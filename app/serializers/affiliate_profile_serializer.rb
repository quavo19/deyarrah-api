class AffiliateProfileSerializer
  def initialize(profile, detail: false)
    @profile = profile
    @detail = detail
  end

  def as_json(*)
    return nil unless profile

    payload = {
      id: profile.id,
      type: "affiliate_profile",
      attributes: {
        user_id: profile.user_id,
        status: profile.status,
        status_label: profile.status_label,
        affiliate_code: profile.affiliate_code,
        full_name: profile.full_name,
        email: profile.email,
        phone: profile.phone,
        country: profile.country,
        city: profile.city,
        social_links: profile.social_links || [],
        promotion_channels: profile.promotion_channels || [],
        audience_size: profile.audience_size,
        content_niche: profile.content_niche,
        reason: profile.reason,
        payout_details: profile.payout_details || {},
        terms_accepted: profile.terms_accepted,
        reviewed_at: profile.reviewed_at&.iso8601,
        rejection_reason: profile.rejection_reason,
        can_reapply: profile.can_reapply?,
        reapplication_available_at: profile.reapplication_available_at&.iso8601,
        reapplication_block_reason: profile.reapplication_block_reason,
        suspended_at: profile.suspended_at&.iso8601,
        created_at: profile.created_at.iso8601,
        updated_at: profile.updated_at.iso8601
      }
    }

    return payload unless @detail

    payload[:attributes][:user] = user_json(profile.user)
    payload[:attributes][:reviewed_by] = user_json(profile.reviewed_by)
    payload[:attributes][:stats] = stats_json
    payload
  end

  private

  attr_reader :profile

  def user_json(user)
    return nil unless user

    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      avatar: user.avatar,
      role: user.role && {
        id: user.role.id,
        name: user.role.name,
        description: user.role.description
      }
    }
  end

  def stats_json
    {
      total_clicks: profile.user.affiliate_clicks.count,
      total_referred_orders: profile.user.affiliate_earnings.select(:order_id).distinct.count,
      total_earned: profile.user.affiliate_earnings.sum(:commission_amount).to_f,
      available_balance: profile.user.affiliate_earnings.where(status: "available").sum(:commission_amount).to_f,
      withdrawn_amount: profile.user.affiliate_earnings.where(status: "withdrawn").sum(:commission_amount).to_f
    }
  end
end
