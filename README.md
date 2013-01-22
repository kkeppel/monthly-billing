# Provide a tool to manage monthly billing

## Current Process
* Create monthly invoice report
** Total orders for the customer for a period of time
* Process every customer invoice using Chase Solution

## Problems with it
* Having to store CC info
* Very manual proccess

## Proposed solution

### Short term, ETA 1 - 2 DAYS
Goal: Move away from handling CC
* Upload current customer information along with CC to Stripe 
** Possible with the use of Stripe API
* Go trough the CSV of customer orders and create invoices/ charges 
### Longer Term: ETA 1 Week
Goal: Web front end to manage it on monthly basis
Road block: Integration with customer dashboard

