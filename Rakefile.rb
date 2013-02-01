require "stripe"
require "csv"
Stripe.api_key = "sk_test_fE9ubfh6kYb2wcNUJsO7X7EF"

existing_customers_count = 0
added_customers_count = 0
desc "Import CSV credit card information in Stripe"

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
		puts "Removed customer #{c.id}"
	end

	File.delete('stripe_customers.csv')
	CSV.open("stripe_customers.csv", "wb") { |csv| csv << ["Company Name", "User Name", "Card Type", "Last 4 Digits", "stripe_id"]}
	puts "Removed #{all_removed_customers} total customers. Peace out guys."

end

task :import_from_csv do
	file = File.read('credit_card_payments_workbook.csv')
	csv = CSV.parse(file, :headers => true)
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
			exp_month = row[18][0..1]
			exp_year = row[18][2..3]
			customer_name = row[1] ? row[1] : row[2]
			description = row[0] + "-" + customer_name + "-" + row[4].split("-").last
			if customer = customers.find{|customer| customer[:description]==description}
				existing_customers_count += 1
			else
				customer = Stripe::Customer.create({
				 :description => description,
				 :card => {
				   :number => row[19],
				   :exp_month => exp_month,
				   :exp_year => exp_year,
				   :name => row[2],
				   :cvc => row[7]
				 }
				})
				added_customers_count += 1

				company_name = customer[:description].split("-")[0]
				user_name = customer[:description].split("-")[1]
				card_type = customer[:description].split("-")[2]
				last4 = customer[:active_card][:last4]
				CSV.open("stripe_customers.csv", "ab") do |a|
					a << [company_name, user_name, card_type, last4, customer[:id]]
				end
			end
			p customer[:id]
		rescue Stripe::CardError => e
			# Since it's a decline, Stripe::CardError will be caught
			p "failed on #{row}"
			body = e.json_body
			err  = body[:error]
			puts "Message is: #{err[:message]}"
		rescue Stripe::InvalidRequestError => e
			# Invalid parameters were supplied to Stripe's API
			p "failed on #{row}"
			body = e.json_body
			err  = body[:error]
			puts "Message is: #{err[:message]}"
		rescue Stripe::AuthenticationError => e
			# Authentication with Stripe's API failed
			# (maybe you changed API keys recently)
			p "failed on #{row}"
			body = e.json_body
			err  = body[:error]
			puts "Message is: #{err[:message]}"
		rescue Stripe::APIConnectionError => e
			# Network communication with Stripe failed
			p "failed on #{row}"
			body = e.json_body
			err  = body[:error]
			puts "Message is: #{err[:message]}"
		rescue Stripe::StripeError => e
			# Display a very generic error to the user, and maybe send
			# yourself an email
			p "failed on #{row}"
			body = e.json_body
			err  = body[:error]
			puts "Message is: #{err[:message]}"
		rescue
			# Something else happened, completely unrelated to Stripe
			p "failed on #{row}"
		end

	end
	puts "Skipped #{existing_customers_count} already existing customer#{"s" if existing_customers_count != 1}. Added #{added_customers_count} new customer#{"s" if added_customers_count != 1}!"
end

task :charge_customer, :customer_id, :amount do |t, args|
	puts "Args were: #{args}\nCustomer_id = #{args[:customer_id]}\nAmount = #{args[:amount]}"

	Stripe::Charge.create(
		:amount => args[:amount],
		:currency => "usd",
		:customer => args[:customer_id]
	)
end

task :add_customer, :order_id, :number, :exp_month, :exp_year, :name, :cvc do |t, args|
	puts "\norder_id: #{args[:order_id]}\nNumber: #{args[:number]}\nExp Month: #{args[:exp_month]}\nExp Year: #{args[:exp_year]}\nName: #{args[:name]}\nCVS: #{args[:cvc]}"

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
		if customer = customers.find{|customer| customer[:description]==args[:order_id]}
			puts "This customer already exists in Stripe."
		else
			customer = Stripe::Customer.create({
				                                   :description => args[:order_id],
				                                   :card => {
					                                   :number => args[:number],
					                                   :exp_month => args[:exp_month],
					                                   :exp_year => args[:exp_year],
					                                   :name => args[:name],
					                                   :cvc => args[:cvc]
				                                   }
			                                   })
			# add new customer to stripe_customers.csv
			company_name = customer[:description].split("-")[0]
			user_name = customer[:description].split("-")[1]
			card_type = customer[:description].split("-")[2]
			last4 = customer[:active_card][:last4]
			CSV.open("stripe_customers.csv", "ab") do |a|
				a << [company_name, user_name, card_type, last4, customer[:id]]
			end
			puts "Added customer #{customer[:description]}"
		end
	rescue Stripe::StripeError => e
		# Display a very generic error to the user, and maybe send
		# yourself an email
		p "failed on #{row}"
		body = e.json_body
		err  = body[:error]
		puts "Message is: #{err[:message]}"
	end

end
