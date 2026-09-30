class AffiliateBalanceService
  RESERVED_WITHDRAWAL_STATUSES = %w[pending approved].freeze

  def self.summary_for(user)
    earnings = user.affiliate_earnings.where.not(status: "cancelled")
    reserved_amount = user.affiliate_withdrawals
      .where(status: RESERVED_WITHDRAWAL_STATUSES)
      .sum(:amount)
      .to_d
    available_earnings = earnings.where(status: "available").sum(:commission_amount).to_d

    {
      total_clicks: user.affiliate_clicks.count,
      total_referred_orders: earnings.select(:order_id).distinct.count,
      total_earned: earnings.sum(:commission_amount).to_f,
      pending_balance: earnings.where(status: "pending").sum(:commission_amount).to_f,
      available_balance: [ available_earnings - reserved_amount, 0.to_d ].max.to_f,
      reserved_withdrawals: reserved_amount.to_f,
      withdrawn_balance: user.affiliate_withdrawals.where(status: "paid").sum(:amount).to_f
    }
  end
end
