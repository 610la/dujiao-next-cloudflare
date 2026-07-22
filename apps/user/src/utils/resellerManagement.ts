type ResellerManagementProfile = {
  status?: string
}

type ResellerManagementSnapshot = {
  opened?: boolean
  can_apply?: boolean
  profile?: ResellerManagementProfile | null
}

export type ResellerManagementState = {
  canApply: boolean
  canSubmitDomain: boolean
  statusKey: string
}

const RESELLER_PROFILE_STATUS_PENDING_REVIEW = 'pending_review'
const RESELLER_PROFILE_STATUS_ACTIVE = 'active'
const RESELLER_PROFILE_STATUS_REJECTED = 'rejected'
const RESELLER_PROFILE_STATUS_DISABLED = 'disabled'

const RESELLER_DOMAIN_STATUS_PENDING_REVIEW = 'pending_review'
const RESELLER_DOMAIN_STATUS_ACTIVE = 'active'
const RESELLER_DOMAIN_STATUS_DISABLED = 'disabled'

export const getResellerProfileStatusKey = (status?: string) => {
  if (status === RESELLER_PROFILE_STATUS_PENDING_REVIEW) return 'pendingReview'
  if (status === RESELLER_PROFILE_STATUS_ACTIVE) return 'active'
  if (status === RESELLER_PROFILE_STATUS_REJECTED) return 'rejected'
  if (status === RESELLER_PROFILE_STATUS_DISABLED) return 'disabled'
  return 'unknown'
}

export const getResellerDomainStatusKey = (status?: string) => {
  if (status === RESELLER_DOMAIN_STATUS_PENDING_REVIEW) return 'pendingReview'
  if (status === RESELLER_DOMAIN_STATUS_ACTIVE) return 'active'
  if (status === RESELLER_DOMAIN_STATUS_DISABLED) return 'disabled'
  return 'unknown'
}

export const isResellerProfileActive = (profile?: ResellerManagementProfile | null) =>
  profile?.status === RESELLER_PROFILE_STATUS_ACTIVE

export const getResellerManagementState = (snapshot?: ResellerManagementSnapshot | null): ResellerManagementState => {
  if (!snapshot) {
    return {
      canApply: false,
      canSubmitDomain: false,
      statusKey: 'unknown',
    }
  }
  if (!snapshot.opened) {
    return {
      canApply: snapshot.can_apply === true,
      canSubmitDomain: false,
      statusKey: 'notOpened',
    }
  }

  const active = isResellerProfileActive(snapshot.profile)
  return {
    canApply: snapshot.can_apply === true,
    canSubmitDomain: active,
    statusKey: getResellerProfileStatusKey(snapshot.profile?.status),
  }
}
