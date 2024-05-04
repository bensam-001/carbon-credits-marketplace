# Carbon Credit Marketplace Module

The Carbon Credit Marketplace module enables the trading of carbon credits on a decentralized platform, allowing users to buy, sell, and dispute carbon credit transactions. It provides functionalities for creating, managing, and resolving disputes related to carbon credit transactions, as well as handling payments and refunds.

## Struct Definitions

### CarbonCredit
- **id**: Unique identifier for the carbon credit.
- **owner**: Address of the owner of the carbon credit.
- **carbon_footprint**: Amount of carbon footprint represented by the credit.
- **validity_period**: Duration of validity for the carbon credit.
- **price**: Price of the carbon credit.
- **escrow**: Balance of SUI tokens held in escrow for the credit.
- **dispute**: Boolean indicating whether there is a dispute regarding the credit.
- **status**: Additional status information associated with the credit.
- **buyer**: Optional address of the buyer in case of a pending transaction.
- **purchased**: Boolean indicating whether the credit has been purchased.
- **created_at**: Timestamp indicating the creation time of the credit.
- **deadline**: Timestamp indicating the deadline for the credit transaction.

### TransactionRecord
- **id**: Unique identifier for the transaction record.
- **seller**: Address of the seller associated with the transaction.
- **review**: Review or feedback associated with the transaction.

## Public - Entry Functions

### create_credit
Creates a new carbon credit listing with the provided carbon footprint, validity period, price, and additional status information.

### buy_credit
Allows users to place bids for purchasing carbon credits listed on the marketplace.

### sell_credit
Enables users to submit carbon credits for sale at a specified price.

### mark_credit_purchased
Marks a carbon credit as purchased after a successful transaction.

### dispute_credit
Initiates a dispute regarding a carbon credit transaction.

### resolve_dispute
Resolves a dispute regarding a carbon credit transaction, either refunding the buyer or paying the seller.

### release_payment
Finalizes the payment for a purchased carbon credit and creates a transaction record.

### add_funds
Adds funds to the escrow balance for a carbon credit transaction.

### cancel_sale
Cancels a carbon credit sale, refunding the buyer if applicable.

### update_credit_price
Updates the price of a carbon credit.

### update_credit_status
Updates the status information associated with a carbon credit.

### add_funds_to_credit
Adds funds to the escrow balance for a specific carbon credit.

### redeem_credits
Redeems carbon credits, deducting them from the user's balance.

### transfer_credits
Transfers carbon credits to another user.

### calculate_credit_expiry
Calculates the expiry time for a carbon credit based on its creation time and validity period.

### check_credit_expiry
Checks whether a carbon credit has expired based on the current time and its expiry time.

## Usage

### Setup

1. Ensure that Rust and Cargo are installed on your development machine.

2. Set up a local instance of the SUI blockchain for testing and deployment purposes.

3. Compile the smart contract code using the Rust compiler and deploy it to your local SUI blockchain node.

### Interacting with the Smart Contract

1. Use the SUI CLI or other deployment tools to interact with the deployed smart contract, providing function arguments and transaction contexts as required.

2. Monitor transaction outputs and blockchain events to track the status of carbon credit listings and transactions.

## Conclusion

The Carbon Credit Marketplace Smart Contract offers a decentralized platform for trading carbon credits, contributing to environmental sustainability efforts. By leveraging blockchain technology, users can engage in transparent and secure transactions, facilitating the exchange of carbon credits while ensuring trust and accountability in the marketplace.