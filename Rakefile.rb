#!/usr/bin/env rake

require "stripe"
require "csv"
Stripe.api_key = "sk_test_fE9ubfh6kYb2wcNUJsO7X7EF"

existing_customers_count = 0
added_customers_count = 0
desc "Import CSV credit card information in Stripe"

task :import_from_csv do
	file = File.read('credit_card_payments_workbook.csv')
	csv = CSV.parse(file, :headers => true)

	customers = Stripe::Customer.all

	csv.each do |row|
		exp_month = row[18][0..1]
		exp_year = row[18][2..3]
		customer_name = row[1] ? row[1] : row[2]
		description = row[0] + "-" + customer_name + "-" + row[3]
		descriptions = customers.collect{|c| c.description}

		if descriptions.include?(description)
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

			new_customer = Stripe::Customer.retrieve(customer.id)
			company_name = new_customer[:description].split("-")[0]
			user_name = new_customer[:description].split("-")[1]
			card_type = new_customer[:description].split("-")[2]
			last4 = new_customer[:active_card][:last4]

			CSV.open("stripe_customers.csv", "ab") do |a|
				a << [company_name, user_name, card_type, last4, new_customer[:id]]
			end
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
