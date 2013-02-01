require 'rake'
require 'spec_helper'
require "stripe"
require "csv"

describe "Rake tasks" do
	before do
		Stripe.api_key = "sk_test_fE9ubfh6kYb2wcNUJsO7X7EF"
		@rake = Rake::Application.new
		Rake.application = @rake
		#Rake.application.rake_require "./Rakefile.rb"
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
			let(:result) {}
			CSV.stub(:open).with("stripe_customers.csv", "wb") { |csv| csv << ["Company Name", "User Name", "Card Type", "Last 4 Digits", "stripe_id"]}
			csv.should include(["Company Name", "User Name", "Card Type", "Last 4 Digits", "stripe_id"])
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
			File.should_receive(:read).with("credit_card_payments_workbook.csv")
			@file = File.read("credit_card_payments_workbook.csv")
		end
		it "should parse csv of customer information" do
			CSV.should_receive(:parse).with(@file, :headers => true).and_return([
				{"CompanyName" => "33Across", "ClientContactName" => "Jennifer Wong", "Name on Card" => "Corey McIntrye",
				"CardType" => "American Express", "CardNumber" => "8870-9077-2852-5338", "ExpirationMonth" => "Feb",
				"ExpirationYear" => "2017", "CardID" => "9182", "Frequency" => "Monthly", "Current?" => "Yes",
				"Hold only?" => "No", "For Single Order?" => "", "Notes" => "", "Chase Payment profile #" => "", "" => "",
				"" => "", "" => "", "2-digit year" => "17", "Expiration Date Clear" => "0217", "CC# clean" => "378282246310005",
				"" => "", "length check" => "16"},
			  {"CompanyName" => "3LM", "ClientContactName" => "Erica Call", "Name on Card" => "Gaurav Mathur",
			   "CardType" => "American Express", "CardNumber" => "8785-9274-7351-3835", "ExpirationMonth" => "Dec",
			   "ExpirationYear" => "2014", "CardID" => "4195", "Frequency" => "Monthly", "Current?" => "Yes",
			   "Hold only?" => "No", "For Single Order?" => "", "Notes" => "", "Chase Payment profile #" => "27863319",
			   "" => "", "" => "", "" => "", "2-digit year" => "14", "Expiration Date Clear" => "1214",
			   "CC# clean" => "378282246310005", "" => "", "length check" => "16"}
			])
			csv = CSV.parse(@file, :headers => true)
			csv.each do |row|
				card = row["CC# clean"]
				exp_month = row["Expiration Date Clear"][0..1]
				exp_year = row["Expiration Date Clear"][2..3]
				name = row["Name on Card"]
				cvc = row["CardID"]
				description = row["CompanyName"] + "-" + row["ClientContactName"] + "-" + row["CardType"]
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