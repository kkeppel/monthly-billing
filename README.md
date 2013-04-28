# Provide a tool to manage monthly billing

## Current Process
* Create monthly invoice report
  * Total orders for the customer for a period of time
* Process every customer invoice using Chase Solution

## Problems with it
* Having to store CC info
* Very manual proccess

## Proposed solution
Goal: Move away from handling CC
* Upload current customer information along with CC to Stripe 
  * Possible with the use of Stripe API
* Go trough the CSV of customer orders and create invoices/ charges
