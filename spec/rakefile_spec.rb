require 'rake'
require 'spec_helper'
require "stripe"
require "csv"
require "yaml"

describe "Rake tasks" do
	before do
		APP_CONFIG = YAML::load_file("config.yml")
		Stripe.api_key = APP_CONFIG["live_api_key"]
		@rake = Rake::Application.new
		Rake.application = @rake
		@rake.init
		@rake.load_rakefile
	end

	describe "rake remove_all_customers" do
		before do
			@task_name = "remove_all_customers"
		end
		it "should connect to Stripe" do
			Stripe::Customer.should_receive(:all).with(:count => 100, :offset => 0)
			Stripe::Customer.all(count: 100, offset: 0)
		end
		it "should open and delete previous csv with stripe customer ids" do
			File.should_receive(:delete).with("stripe_customers.csv")
			File.delete('stripe_customers.csv')
		end
		it "should create a new csv for stripe customer ids with headers" do
			CSV.should_receive(:open).with("stripe_customers.csv", "wb")
			CSV.open("stripe_customers.csv", "wb") { |csv| csv << ["Company Name", "User Name", "Card Type", "Last 4 Digits", "order_id", "stripe_id"]}
			File.read("stripe_customers.csv").should include("Company Name", "User Name", "Card Type", "Last 4 Digits", "order_id", "stripe_id")
		end

	end

	describe "rake import_from_csv" do
		before do
			@task_name = "import_from_csv"
		end
		it "should connect to Stripe" do
			Stripe::Customer.should_receive(:all).with(:count => 100, :offset => 0)
			@customers = Stripe::Customer.all(count: 100, offset: 0)
		end
		it "should load csv of customer information" do
			File.should_receive(:read).with("test_data.csv")
			@file = File.read("test_data.csv")
		end
		it "should parse csv of customer information" do
			CSV.should_receive(:parse).with(@file, :headers => true).and_return([
				{"CompanyName" => "33Across", "ClientContactName" => "Jennifer Wong", "NameOnCard" => "Corey McIntrye",
				"CardType" => "American Express", "CardID" => "9182", "ExpirationDateClean" => "0217",
				"CardNumberClean" => "378282246310005", "CompanyID" => "176", "ContactID" => "205", "City" => "NYC" },
			  {"CompanyName" => "3LM", "ClientContactName" => "Erica Call", "NameOnCard" => "Gaurav Mathur",
			  "CardType" => "American Express", "CardID" => "4195", "ExpirationDateClean" => "1214",
			  "CardNumberClean" => "378282246310005", "CompanyID" => "384", "ContactID" => "608", "City" => "SF"}
			])
			csv = CSV.parse(@file, :headers => true)
			csv.each do |row|
				card = row["CardNumberClean"]
				exp_month = row["ExpirationDateClean"][0..1]
				exp_year = row["ExpirationDateClean"][2..3]
				name = row["NameOnCard"]
				cvc = row["CardID"]
				description = row["CompanyID"] + "-" + row["ContactID"] + "-" + card.to_s[-4,4] +"-" + row["City"]
				card.should_not be_nil
				exp_month.should_not be_nil
				exp_year.should_not be_nil
				name.should_not be_nil
				cvc.should_not be_nil
				description.should_not be_nil
			end
		end
		it "should open the new CSV to record the Stripe customer ID" do
			CSV.should_receive(:open).with("stripe_customers.csv")
			CSV.open("stripe_customers.csv")
		end
	end

end