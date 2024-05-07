module carbon_credit_marketplace::carbon_credit_marketplace {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some};

    // Errors
    const EINVALID_BID: u64 = 1;
    const EINVALID_TRANSACTION: u64 = 2;
    const EDISPUTE: u64 = 3;
    const EALREADY_RESOLVED: u64 = 4;
    const ENOT_PARTICIPANT: u64 = 5;
    const EINVALID_REDEMPTION: u64 = 6;
    const EDEADLINE_PASSED: u64 = 7;
    const EINSUFFICIENT_BALANCE: u64 = 8;

    // Struct definitions

    // CarbonCredit struct
    struct CarbonCredit has key, store {
        id: UID,
        owner: address,
        carbon_footprint: u64,
        validity_period: u64,
        price: u64,
        escrow: Balance<SUI>,
        dispute: bool,
        status: vector<u8>,
        buyer: Option<address>,
        purchased: bool,
        created_at: u64,
        deadline: u64,
    }

    // TransactionRecord struct
    struct TransactionRecord has key, store {
        id: UID,
        seller: address,
        review: vector<u8>,
    }

    // Accessors
    fn get_credit_footprint(credit: &CarbonCredit): u64 {
        credit.carbon_footprint
    }

    fn get_credit_price(credit: &CarbonCredit): u64 {
        credit.price
    }

    fn get_credit_status(credit: &CarbonCredit): &vector<u8> {
        &credit.status
    }

    fn get_credit_deadline(credit: &CarbonCredit): u64 {
        credit.deadline
    }

    // Public - Entry functions

    // Create a new carbon credit
    public entry fun create_credit(
        carbon_footprint: u64,
        validity_period: u64,
        price: u64,
        clock: &Clock,
        duration: u64,
        open_status: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Add authentication or checks to prevent unauthorized creation
        let credit_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        transfer::share_object(CarbonCredit {
            id: credit_id,
            owner: tx_context::sender(ctx),
            buyer: none(),
            carbon_footprint,
            validity_period,
            price,
            escrow: balance::zero(),
            dispute: false,
            status: open_status,
            purchased: false,
            created_at: clock::timestamp_ms(clock),
            deadline,
        });
    }

    // Bid for carbon credit
    public entry fun buy_credit(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(!is_some(&credit.buyer), EINVALID_BID);
        credit.buyer = some(tx_context::sender(ctx));
        credit.purchased = true;
    }

    // Submit carbon credit for sale
    public entry fun sell_credit(credit: &mut CarbonCredit, price: u64, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), EINVALID_TRANSACTION);
        credit.price = price;
    }

    // Raise a dispute
    public entry fun dispute_credit(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), EDISPUTE);
        credit.dispute = true;
    }

    // Resolve dispute if any between buyer and seller
    public entry fun resolve_dispute(credit: &mut CarbonCredit, resolved: bool, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), EDISPUTE);
        assert!(credit.dispute, EALREADY_RESOLVED);
        let buyer = match credit.buyer {
            some(addr) => addr,
            none() => return, // Or handle the case when buyer is none
        };
        let escrow_amount = balance::value(&credit.escrow);
        let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
        if resolved {
            // Transfer funds to the seller
            transfer::public_transfer(escrow_coin, credit.owner);
        } else {
            // Refund funds to the buyer
            transfer::public_transfer(escrow_coin, buyer);
        };

        // Reset credit state
        credit.buyer = none();
        credit.purchased = false;
        credit.dispute = false;
    }

    // Release payment to the seller after credit is purchased
    public entry fun release_payment(credit: &mut CarbonCredit, clock: &Clock, review: vector<u8>, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), ENOT_PARTICIPANT);
        assert!(credit.purchased && !credit.dispute, EINVALID_TRANSACTION);
        assert!(clock::timestamp_ms(clock) > credit.deadline, EDEADLINE_PASSED);
        let buyer = match credit.buyer {
            some(addr) => addr,
            none() => return, // Or handle the case when buyer is none
        };
        let escrow_amount = balance::value(&credit.escrow);
        assert!(escrow_amount > 0, EINSUFFICIENT_BALANCE); // Ensure there are enough funds in escrow
        let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
        // Transfer funds to the seller
        transfer::public_transfer(escrow_coin, credit.owner);

        // Create a new transaction record
        let transaction_record = TransactionRecord {
            id: object::new(ctx),
            seller: credit.owner,
            review,
        };

        // Change accessibility of transaction record
        transfer::public_transfer(transaction_record, credit.owner);

        // Reset credit state
        credit.buyer = none();
        credit.purchased = false;
        credit.dispute = false;
    }

    // Add more funds to escrow
    public entry fun add_funds(credit: &mut CarbonCredit, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == credit.owner, ENOT_PARTICIPANT);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut credit.escrow, added_balance);
    }

    // Cancel credit sale
    public entry fun cancel_sale(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(
            credit.owner == tx_context::sender(ctx) || is_some(&credit.buyer) && *credit.buyer.borrow() == tx_context::sender(ctx),
            ENOT_PARTICIPANT
        );

        // Refund funds to the buyer if credit not yet purchased and no dispute
        if let some(buyer_addr) = credit.buyer {
            if !credit.purchased && !credit.dispute {
                let escrow_amount = balance::value(&credit.escrow);
                let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
                transfer::public_transfer(escrow_coin, buyer_addr);
            }
        };

        // Reset credit state
        credit.buyer = none();
        credit.purchased = false;
        credit.dispute = false;
    }

    // Update credit price
    public entry fun update_credit_price(credit: &mut CarbonCredit, new_price: u64, ctx: &mut TxContext) {
        assert!(credit.owner== tx_context::sender(ctx), ENOT_PARTICIPANT);
        // Add additional checks or validations if needed
        credit.price = new_price;
    }

    // Update credit status
    public entry fun update_credit_status(credit: &mut CarbonCredit, new_status: vector<u8>, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), ENOT_PARTICIPANT);
        // Add additional checks or validations if needed
        credit.status = new_status;
    }

    // Redeem carbon credits
    public entry fun redeem_credits(amount: u64, ctx: &mut TxContext) {
        // Implementation for redeeming carbon credits, deducting from user's balance, etc.
    }

    // Transfer carbon credits to another user
    public entry fun transfer_credits(credit: &mut CarbonCredit, recipient: address, ctx: &mut TxContext) {
        // Implementation for transferring carbon credits between users
    }

    // Check carbon credit expiry
    public entry fun is_credit_expired(credit: &CarbonCredit, clock: &Clock): bool {
        let current_time = clock::timestamp_ms(clock);
        let expiry_time = credit.created_at + credit.validity_period;
        current_time > expiry_time
    }
}
