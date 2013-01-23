#!/usr/bin/env rake

require "stripe"
require "csv"
Stripe.api_key = "sk_test_fE9ubfh6kYb2wcNUJsO7X7EF"

existing_customers_count = 0
added_customers_count = 0
desc "Import CSV credit card information in Stripe"

task :import_from_csv do
	file = File.read('cards.csv')
	csv = CSV.parse(file, :headers => true)

	customers = Stripe::Customer.all

	csv.each do |row|
		exp_month = row[2][0..1]
		exp_year = row[2][2..3]
		description = row[0]
		descriptions = customers.collect{|c| c.description}

		if descriptions.include?(description)
			existing_customers_count += 1
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
			added_customers_count += 1
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
