require "stripe"
require "csv"
Stripe.api_key = "sk_test_fE9ubfh6kYb2wcNUJsO7X7EF"


file = File.read('lib/tasks/cards.csv')
csv = CSV.parse(file, :headers => true)
i = 0
x = 0
desc "Import CSV credit card information in Stripe"

task :import_from_csv => [:environment] do
	csv.each do |row|
		exp_month = row[2][0..1]
		exp_year = row[2][2..3]
		description = row[0]

		customers = Stripe::Customer.all
		descriptions = customers.collect{|c| c.description}

		if descriptions.include?(description)
			i += 1
		else
			Stripe::Customer.create({
        :description => row[0],
        :card => {
          :number => row[1],
          :exp_month => exp_month,
          :exp_year => exp_year,
          :name => row[3]
        }
      })
			x += 1
		end
	end
	puts "Skipped #{i} already existing customer#{"s" if x != 1}. Added #{x} new customer#{"s" if x != 1}!"
end

task :charge_customer, :customer_id, :amount do |t, args|
	puts "Args were: #{args}\nCustomer_id = #{args[:customer_id]}\nAmount = #{args[:amount]}"

	Stripe::Charge.create(
		:amount => args[:amount],
	  :currency => "usd",
	  :customer => args[:customer_id]
	)
end
