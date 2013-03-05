require "stripe"
require "csv"
require "yaml"

$LOAD_PATH << File.dirname(__FILE__)
APP_CONFIG = YAML::load_file("config.yml")

Stripe.api_key = APP_CONFIG["live_api_key"]

existing_customers_count = 0
added_customers_count = 0
desc "Import CSV credit card information in Stripe"

### -----------------------------------

def read_csv(csv)
	file = File.read(csv)
	CSV.parse(file, :headers => true)
end

### -----------------------------------

def append_to_successful_charges_csv(customer_id, amount, charge_id, paid, refunded, created_at)
	CSV.open("successful_charges.csv", "ab") do |a|
		a << [customer_id, amount, charge_id, paid, refunded, created_at]
	end
end

### -----------------------------------

def append_to_stripe_customers_csv(company_name, user_name, card_type, las4, order_id, customer_id)
	CSV.open("stripe_customers.csv", "ab") do |a|
		a << [company_name, user_name, card_type, last4, order_id, customer_id]
	end
end

### -----------------------------------

def create_customer(description, number, exp_month, exp_year, name, cvc)
	Stripe::Customer.create({
		:description => description,
		:card => {
			:number => number,
			:exp_month => exp_month,
			:exp_year => exp_year,
			:name => name,
			:cvc => cvc
		}
	})
end

def charge_customer(customer, amount)
	Stripe::Charge.create(:customer => customer, :amount => amount, :currency => "usd")
end

### -----------------------------------

def card_error(e, row)
	# Since it's a decline, Stripe::CardError will be caught
	p "failed on #{row}"
	body = e.json_body
	err  = body[:error]
	puts "Message is: #{err[:message]}"
end

def invalid_request_error(e, row)
	# Invalid parameters were supplied to Stripe's API
	p "failed on #{row}"
	body = e.json_body
	err  = body[:error]
	puts "Message is: #{err[:message]}"
end

def authentication_error(e, row)
	# Authentication with Stripe's API failed
	# (maybe you changed API keys recently)
	p "failed on #{row}"
	body = e.json_body
	err  = body[:error]
	puts "Message is: #{err[:message]}"
end

def api_connection_error(e, row)
	# Network communication with Stripe failed
	p "failed on #{row}"
	body = e.json_body
	err  = body[:error]
	puts "Message is: #{err[:message]}"
end

def stripe_error(e, row)
	# Display a very generic error to the user, and maybe send
	# yourself an email
	p "failed on #{row}"
	body = e.json_body
	err  = body[:error]
	puts "Message is: #{err[:message]}"
end

### -----------------------------------

task :remove_all_customers do
	all_removed_customers = 0
	customers=[]
	count=100
	offset=0
	until count<100
		stripe_request = Stripe::Customer.all(count: count,offset: offset)
		customers.concat stripe_request.data
		count = stripe_request.data.count
		offset+=count
	end
	customers.each do |c|
		customer = Stripe::Customer.retrieve(c.id)
		customer.delete
		all_removed_customers += 1
		puts "Removed customer #{c.description}"
	end

	File.delete('stripe_customers.csv')
	CSV.open("stripe_customers.csv", "wb") { |csv| csv << ["Company Name", "User Name", "Card Type", "Last 4 Digits", "order_id", "stripe_id"]}
	puts "Removed #{all_removed_customers} total customers. Peace out guys."
end

### -----------------------------------

task :import_from_csv do
	csv = read_csv('cc_import_workbook_AL.csv')
	customers=[]
	count=100
	offset=0
	until count<100
		stripe_request = Stripe::Customer.all(count: count,offset: offset)
		customers.concat stripe_request.data
		count = stripe_request.data.count
		offset+=count
	end
	csv.each do |row|
		begin
			exp_month = row[5][0..1]
			exp_year = row[5][2..3]
			customer_name = row[1] ? row[1] : row[2]
			description = row[0] + "-" + customer_name + "-" + row[9] + "-" + row[6].to_s[-4,4]
			if customer = customers.find{|customer| customer[:description]==description}
				existing_customers_count += 1
			else
				customer = create_customer(description, row[6], exp_month, exp_year, row[2], row[4])
				added_customers_count += 1
				append_to_stripe_customers_csv(row[0], customer_name, row[3], customer[:active_card][:last4], customer[:description], customer[:id])
			end
			p customer[:description]
		rescue Stripe::CardError => e
			card_error(e, row)
		rescue Stripe::InvalidRequestError => e
			invalid_request_error(e, row)
		rescue Stripe::AuthenticationError => e
			authentication_error(e, row)
		rescue Stripe::APIConnectionError => e
			api_connection_error(e, row)
		rescue Stripe::StripeError => e
			stripe_error(e, row)
		rescue
			# Something else happened, completely unrelated to Stripe
			p "failed on #{row}"
		end
	end
	puts "Skipped #{existing_customers_count} already existing customer#{"s" if existing_customers_count != 1}. Added #{added_customers_count} new customer#{"s" if added_customers_count != 1}!"
end

### -----------------------------------

task :charge_customer, :customer_id, :amount do |t, args|
	puts "Args were: #{args}\nCustomer_id = #{args[:customer_id]}\nAmount = #{args[:amount]}"
	charge = charge_customer(args[:customer_id], args[:amount])
	append_to_successful_charges_csv(args[:customer_id], args[:amount], args[:charge_id], charge[:paid], charge[:refunded], charge[:created]) 
end

### -----------------------------------

task :charge_customers do
	csv = read_csv('charges.csv')
  charges = 0
	csv.each do |row|
		begin
			charge = charge_customer(row[0], row[1])
			append_to_successful_charges_csv(row[0], row[1], charge[:id], charge[:paid], charge[:refunded], charge[:created])
			charges += 1
			puts "charged customer #{row[0]} #{amount}"
		rescue Stripe::CardError => e
			card_error(e, row)
		rescue Stripe::InvalidRequestError => e
			invalid_request_error(e, row)
		rescue Stripe::AuthenticationError => e
			authentication_error(e, row)
		rescue Stripe::APIConnectionError => e
			api_connection_error(e, row)
		rescue Stripe::StripeError => e
			stripe_error(e, row)
		rescue
			# Something else happened, completely unrelated to Stripe
			p "failed on #{row}"
		end
	end
	puts "Charged #{charges} customer#{"s" if charges != 1}!"
end

### -----------------------------------

task :refund_charges do
	csv = read_csv('refund_charges.csv')
  refunds = 0
	csv.each do |row|
		begin
			charge = Stripe::Charge.retrieve(row[0])
			charge.refund
			append_to_successful_charges_csv(charge[:customer], charge[:amount], row[0], charge[:paid], charge[:refunded], charge[:created]) 
			charges += 1
			puts "charged customer #{row[0]} #{amount}"
		rescue Stripe::CardError => e
			card_error(e, row)
		rescue Stripe::InvalidRequestError => e
			invalid_request_error(e, row)
		rescue Stripe::AuthenticationError => e
			authentication_error(e, row)
		rescue Stripe::APIConnectionError => e
			api_connection_error(e, row)
		rescue Stripe::StripeError => e
			stripe_error(e, row)
		rescue
			# Something else happened, completely unrelated to Stripe
			p "failed on #{row}"
		end
	end
	puts "Refunded #{refunds} customer#{"s" if refunds != 1}!"	
end

### -----------------------------------

task :refund_charge, :charge_id do |t, args|
	puts "Args were: #{args}\charge_id = #{args[:charge_id]}"
	charge = Stripe::Charge.retrieve(args[:charge_id])
	charge.refund
	append_to_successful_charges_csv(charge[:customer], charge[:amount], args[:charge_id], charge[:paid], charge[:refunded], charge[:created]) 
end

### -----------------------------------

task :add_customer, :number, :exp_month, :exp_year, :name, :cvc, :company_name, :card_type, :city do |t, args|
	puts "\ncity: #{args[:city]}\nNumber: #{args[:number]}\nExp Month: #{args[:exp_month]}\nExp Year: #{args[:exp_year]}\nName: #{args[:name]}\nCVC: #{args[:cvc]}\nCompany Name: #{args[:company_name]}\nCard Type: #{args[:card_type]}"
	customers=[]
	count=100
	offset=0
	until count<100
		stripe_request = Stripe::Customer.all(count: count,offset: offset)
		customers.concat stripe_request.data
		count = stripe_request.data.count
		offset+=count
	end
	begin
		description = args[:company_name] + "-" + args[:name] + "-" + args[:city] + "-" + args[:number].to_s[-4,4] 
		if customer = customers.find{|customer| customer[:description]==description}
			puts "This customer already exists in Stripe."
		else
			customer = create_customer(description, args[:number], args[:exp_month], args[:exp_year], args[:name], args[:cvc])
			append_to_stripe_customers_csv(args[:company_name], args[:name], args[:card_type], customer[:active_card][:last4], customer[:description], customer[:id])
			puts "Added customer #{customer[:description]}"
		end
	rescue Stripe::CardError => e
			card_error(e, row)
	rescue Stripe::InvalidRequestError => e
		invalid_request_error(e, row)
	rescue Stripe::AuthenticationError => e
		authentication_error(e, row)
	rescue Stripe::APIConnectionError => e
		api_connection_error(e, row)
	rescue Stripe::StripeError => e
		stripe_error(e, row)
	rescue
		# Something else happened, completely unrelated to Stripe
		p "failed on #{row}"
	end

end
