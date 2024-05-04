module carbon_credit_marketplace::carbon_credit_marketplace {
    use sui::{transfer, sui::SUI, coin::{Self, Coin}, clock::{Self, Clock}, object::{Self, UID}, balance::{Self, Balance}, tx_context::{Self, TxContext}};
    use std::option::{Option, none, some, is_some};

    const ERR_INVALID_BID: u64 = 1;
    const ERR_INVALID_TRANSACTION: u64 = 2;
    const ERR_DISPUTE_ACTIVE: u64 = 3;
    const ERR_ALREADY_RESOLVED: u64 = 4;
    const ERR_NOT_PARTICIPANT: u64 = 5;
    const ERR_INVALID_REDEMPTION: u64 = 6;
    const ERR_DEADLINE_PASSED: u64 = 7;
    const ERR_INSUFFICIENT_BALANCE: u64 = 8;
    
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

    struct TransactionRecord has key, store {
        id: UID,
        seller: address,
        review: vector<u8>,
    }
    
    public fun get_credit_footprint(credit: &CarbonCredit): u64 {
        credit.carbon_footprint
    }

    public fun get_credit_price(credit: &CarbonCredit): u64 {
        credit.price
    }

    public fun get_credit_status(credit: &CarbonCredit): vector<u8> {
        credit.status
    }

    public fun get_credit_deadline(credit: &CarbonCredit): u64 {
        credit.deadline
    }

    public entry fun create_credit(carbon_footprint: u64, validity_period: u64, price: u64, clock: &Clock, duration: u64, open_status: vector<u8>, ctx: &mut TxContext) {
        let credit_id = UID::new();
        let now = clock::now(clock);
        let deadline = now + duration;
        let new_credit = CarbonCredit {
            id: credit_id,
            owner: tx_context::sender(ctx),
            buyer: none(),
            carbon_footprint,
            validity_period,
            price,
            escrow: Balance::zero(),
            dispute: false,
            status: open_status,
            purchased: false,
            created_at: now,
            deadline,
        };
        transfer::publish(new_credit, ctx);
    }

    public entry fun buy_credit(credit_id: UID, amount: Coin<SUI>, ctx: &mut TxContext) {
        let credit = tx_context::borrow_global_mut::<CarbonCredit>(credit_id, ctx);
        assert!(!is_some(&credit.buyer), ERR_INVALID_BID);
        assert!(credit.owner != tx_context::sender(ctx), ERR_INVALID_TRANSACTION);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut credit.escrow, added_balance);
        credit.buyer = some(tx_context::sender(ctx));
    }

    public entry fun resolve_dispute(credit_id: UID, resolved: bool, ctx: &mut TxContext) {
        let credit = tx_context::borrow_global_mut::<CarbonCredit>(credit_id, ctx);
        assert!(credit.dispute, ERR_ALREADY_RESOLVED);
        assert!(is_some(&credit.buyer), ERR_INVALID_BID);

        let escrow_amount = balance::value(&credit.escrow);
        assert!(escrow_amount > 0, ERR_INSUFFICIENT_BALANCE);

        let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
        let buyer_address = *borrow(&credit.buyer).unwrap();

        if (resolved) {
            transfer::public_transfer(escrow_coin, credit.owner);
        } else {
            transfer::public_transfer(escrow_coin, buyer_address);
        }

        credit.dispute = false;
        credit.buyer = none();
        credit.purchased = false;
    }

    public entry fun release_payment(credit_id: UID, ctx: &mut TxContext) {
        let credit = tx_context::borrow_global_mut::<CarbonCredit>(credit_id, ctx);
        assert!(credit.purchased && !credit.dispute, ERR_INVALID_TRANSACTION);
        let now = clock::now(clock);
        assert!(now > credit.deadline, ERR_DEADLINE_PASSED);
        assert!(is_some(&credit.buyer), ERR_INVALID_BID);

        let buyer_address = *borrow(&credit.buyer).unwrap();
        let escrow_amount = balance::value(&credit.escrow);
        assert!(escrow_amount > 0, ERR_INSUFFICIENT_BALANCE);
        
        let escrow_coin = coin::take(&mut credit.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, credit.owner);

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
