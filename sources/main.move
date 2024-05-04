module carbon_credit_marketplace::carbon_credit_marketplace {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some, is_some, contains, borrow};
    
    // Errors
    const EInvalidBid: u64 = 1;
    const EInvalidTransaction: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotParticipant: u64 = 5;
    const EInvalidRedemption: u64 = 6;
    const EDeadlinePassed: u64 = 7;
    const EInsufficientBalance: u64 = 8;
    
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
    public entry fun get_credit_footprint(credit: &CarbonCredit): u64 {
        credit.carbon_footprint
    }

    public entry fun get_credit_price(credit: &CarbonCredit): u64 {
        credit.price
    }

    public entry fun get_credit_status(credit: &CarbonCredit): vector<u8> {
        credit.status
    }

    public entry fun get_credit_deadline(credit: &CarbonCredit): u64 {
        credit.deadline
    }

    // Public - Entry functions

    // Create a new carbon credit
    public entry fun create_credit(carbon_footprint: u64, validity_period: u64, price: u64, clock: &Clock, duration: u64, open: vector<u8>, ctx: &mut TxContext) {
        
        let credit_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        transfer::share_object(CarbonCredit {
            id: credit_id,
            owner: tx_context::sender(ctx),
            buyer: none(),
            carbon_footprint: carbon_footprint,
            validity_period: validity_period,
            price: price,
            escrow: balance::zero(),
            dispute: false,
            status: open,
            purchased: false,
            created_at: clock::timestamp_ms(clock),
            deadline: deadline,
        });
    }
    
    // Bid for carbon credit
    public entry fun buy_credit(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(!is_some(&credit.buyer), EInvalidBid);
        credit.buyer = some(tx_context::sender(ctx));
    }
    
    // Submit carbon credit for sale
    public entry fun sell_credit(credit: &mut CarbonCredit, price: u64, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), EInvalidTransaction);
        credit.price = price;
    }

    // Mark carbon credit as purchased
    public entry fun mark_credit_purchased(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(is_some(&credit.buyer), ENotParticipant);
        credit.purchased = true;
    }
    
    // Raise a dispute
    public entry fun dispute_credit(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), EDispute);
        credit.dispute = true;
    }
    
    // Resolve dispute if any between buyer and seller
    public entry fun resolve_dispute(credit: &mut CarbonCredit, resolved: bool, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), EDispute);
        assert!(credit.dispute, EAlreadyResolved);
        assert!(is_some(&credit.buyer), EInvalidBid);
        let escrow_amount = balance::value(&credit.escrow);
        let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
        if (resolved) {
            let buyer = *borrow(&credit.buyer);
            // Transfer funds to the seller
            transfer::public_transfer(escrow_coin, credit.owner);
        } else {
            // Refund funds to the buyer
            transfer::public_transfer(escrow_coin, *borrow(&credit.buyer));
        };
        
        // Reset credit state
        credit.buyer = none();
        credit.purchased = false;
        credit.dispute = false;
    }
    
    // Release payment to the seller after credit is purchased
    public entry fun release_payment(credit: &mut CarbonCredit, clock: &Clock, review: vector<u8>, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), ENotParticipant);
        assert!(credit.purchased && !credit.dispute, EInvalidTransaction);
        assert!(clock::timestamp_ms(clock) > credit.deadline, EDeadlinePassed);
        assert!(is_some(&credit.buyer), EInvalidBid);
        let buyer = *borrow(&credit.buyer);
        let escrow_amount = balance::value(&credit.escrow);
        assert!(escrow_amount > 0, EInsufficientBalance); // Ensure there are enough funds in escrow
        let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
        // Transfer funds to the seller
        transfer::public_transfer(escrow_coin, credit.owner);

        // Create a new transaction record
        let transaction_record = TransactionRecord {
            id: object::new(ctx),
            seller: credit.owner,
            review: review,
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
        assert!(tx_context::sender(ctx) == credit.owner, ENotParticipant);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut credit.escrow, added_balance);
    }
    
    // Cancel credit sale
    public entry fun cancel_sale(credit: &mut CarbonCredit, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx) || contains(&credit.buyer, &tx_context::sender(ctx)), ENotParticipant);
        
        // Refund funds to the buyer if credit not yet purchased
        if (is_some(&credit.buyer) && !credit.purchased && !credit.dispute) {
            let escrow_amount = balance::value(&credit.escrow);
            let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, *borrow(&credit.buyer));
        };
        
        // Reset credit state
        credit.buyer = none();
        credit.purchased = false;
        credit.dispute = false;
    }

    // Update credit price
    public entry fun update_credit_price(credit: &mut CarbonCredit, new_price: u64, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), ENotParticipant);
        credit.price = new_price;
    }

    // Update credit status
    public entry fun update_credit_status(credit: &mut CarbonCredit, new_status: vector<u8>, ctx: &mut TxContext) {
        assert!(credit.owner == tx_context::sender(ctx), ENotParticipant);
        credit.status = new_status;
    }

    // Add more funds to escrow
    public entry fun add_funds_to_credit(credit: &mut CarbonCredit, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == credit.owner, ENotParticipant);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut credit.escrow, added_balance);
    }
    

    // Redeem carbon credits
    public entry fun redeem_credits(amount: u64, ctx: &mut TxContext) {
        // Implementation for redeeming carbon credits, deducting from user's balance, etc.
    }
    
    // Transfer carbon credits to another user
    public entry fun transfer_credits(credit: &mut CarbonCredit, recipient: address, ctx: &mut TxContext) {
        // Implementation for transferring carbon credits between users
    }
    // Calculate carbon credit expiry
    public entry fun calculate_credit_expiry(credit: &CarbonCredit, clock: &Clock): u64 {
    let creation_time = credit.created_at;
    let validity_period = credit.validity_period;
    let expiry_time = creation_time + validity_period;
    expiry_time
    }
  // Check carbon credit expiry
   public entry fun check_credit_expiry(credit: &CarbonCredit, clock: &Clock): bool {
    let current_time = clock::timestamp_ms(clock);
    let expiry_time = calculate_credit_expiry(credit, clock);
    let is_expired = current_time > expiry_time;
    is_expired
    }

}
