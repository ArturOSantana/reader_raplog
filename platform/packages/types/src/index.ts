/**
 * @lumen/types
 *
// ─────────────────────────────────────────────────────────────
// Auth / Profile
// ─────────────────────────────────────────────────────────────

/** Roles do sistema. Controlam o acesso ao Admin Console. */
export type UserRole =
  | 'user'
  | 'super_admin'
  | 'admin'
  | 'support'
  | 'moderator'
  | 'analyst'

export interface Profile {
  id: string
  username: string
  avatar_url: string | null
  bio: string | null
  full_name: string | null
  is_public: boolean
  role: UserRole
  created_at: string
  updated_at: string
  // stats opcionais (joins)
  books_read?: number
  total_pages?: number
  current_streak?: number
}

// ─────────────────────────────────────────────────────────────
// Books
// ─────────────────────────────────────────────────────────────

export type BookStatus = 'reading' | 'want_to_read' | 'read' | 'abandoned'

export interface Book {
  id: string
  user_id: string
  google_books_id: string | null
  title: string
  author: string | null
  cover_url: string | null
  total_pages: number | null
  genre: string | null
  publisher: string | null
  isbn: string | null
  language: string | null
  status: BookStatus
  start_date: string | null
  end_date: string | null
  rating: number | null
  current_page: number | null
  created_at: string
  updated_at: string
}

/** Metadados públicos de um livro (página indexada). */
export interface BookMetadata {
  id: string
  google_books_id: string
  slug: string
  title: string
  authors: string[]
  description: string | null
  cover_url: string | null
  publisher: string | null
  published_date: string | null
  isbn_13: string | null
  isbn_10: string | null
  page_count: number | null
  categories: string[]
  language: string | null
  reader_count: number
  avg_rating: number | null
  review_count: number
  created_at: string
  updated_at: string
}

// ─────────────────────────────────────────────────────────────
// Reading Sessions
// ─────────────────────────────────────────────────────────────

export interface ReadingSession {
  id: string
  user_id: string
  book_id: string
  started_at: string
  ended_at: string | null
  duration_minutes: number | null
  start_page: number | null
  end_page: number | null
  pages_read: number | null
  notes: string | null
  created_at: string
}

// ─────────────────────────────────────────────────────────────
// Notes & Highlights
// ─────────────────────────────────────────────────────────────

export type NoteType = 'observation' | 'reflection' | 'highlight'

export interface Note {
  id: string
  user_id: string
  book_id: string
  type: NoteType
  content: string
  page_number: number | null
  created_at: string
  updated_at: string
}

export interface Highlight {
  id: string
  user_id: string
  book_id: string
  text: string
  page_number: number | null
  created_at: string
}

// ─────────────────────────────────────────────────────────────
// Goals
// ─────────────────────────────────────────────────────────────

export type GoalType = 'daily_pages' | 'daily_minutes' | 'yearly_books' | 'monthly_pages'
export type GoalPeriod = 'daily' | 'weekly' | 'monthly' | 'yearly'

export interface Goal {
  id: string
  user_id: string
  type: GoalType
  target_value: number
  period: GoalPeriod
  created_at: string
  updated_at: string
}

// ─────────────────────────────────────────────────────────────
// Book Clubs
// ─────────────────────────────────────────────────────────────

export type ClubStatus = 'active' | 'on_vacation' | 'closed' | 'archived'
export type ClubVisibility = 'public' | 'private' | 'invite_only'
export type ClubCategory =
  | 'general' | 'fiction' | 'nonfiction' | 'fantasy'
  | 'scifi' | 'romance' | 'mystery' | 'biography'
  | 'history' | 'selfhelp' | 'children' | 'classics'

export interface BookClub {
  id: string
  slug: string
  name: string
  description: string | null
  cover_url: string | null
  category: ClubCategory
  visibility: ClubVisibility
  status: ClubStatus
  invite_code: string | null
  current_book_id: string | null
  current_book_title: string | null
  current_book_author: string | null
  current_book_cover_url: string | null
  member_count?: number
  created_at: string
}

export type ClubMemberRole = 'owner' | 'admin' | 'member'

export interface ClubMember {
  user_id: string
  club_id: string
  role: ClubMemberRole
  joined_at: string
  profile?: Profile
}

// ─────────────────────────────────────────────────────────────
// Reviews
// ─────────────────────────────────────────────────────────────

export interface ClubReview {
  id: string
  club_id: string
  book_history_id: string
  user_id: string
  rating: number
  content: string | null
  created_at: string
  updated_at: string
  profile?: Profile
}

export interface BookReview {
  id: string
  book_metadata_id: string
  user_id: string
  rating: number
  content: string | null
  contains_spoiler: boolean
  created_at: string
  updated_at: string
  profile?: Pick<Profile, 'id' | 'username' | 'avatar_url'>
}

// ─────────────────────────────────────────────────────────────
// Achievements
// ─────────────────────────────────────────────────────────────

export interface Achievement {
  id: string
  key: string
  name: string
  description: string
  icon: string | null
  xp_reward: number
  created_at: string
}

export interface UserAchievement {
  id: string
  user_id: string
  achievement_id: string
  unlocked_at: string
  achievement?: Achievement
}

// ─────────────────────────────────────────────────────────────
// Stats / Analytics
// ─────────────────────────────────────────────────────────────

export interface DailyStat {
  date: string
  total_minutes: number
  total_pages: number
  session_count: number
}

// ─────────────────────────────────────────────────────────────
// Admin — métricas de plataforma
// ─────────────────────────────────────────────────────────────

export interface PlatformMetrics {
  total_users: number
  active_users_7d: number
  active_users_30d: number
  total_books: number
  total_sessions: number
  total_clubs: number
  total_reviews: number
  avg_session_minutes: number
  new_users_this_month: number
}

/** Roles que têm acesso ao Admin Console. */
export const ADMIN_ROLES: UserRole[] = ['super_admin', 'admin', 'support', 'moderator', 'analyst']

export function isAdminRole(role: string | null | undefined): role is UserRole {
  return ADMIN_ROLES.includes(role as UserRole)
}

// ─────────────────────────────────────────────────────────────
// Subscriptions (spec §17)
// ─────────────────────────────────────────────────────────────

export type SubPlan    = 'free' | 'premium_monthly' | 'premium_annual'
export type SubStatus  = 'trialing' | 'active' | 'past_due' | 'canceled' | 'expired'
export type SubChannel = 'stripe' | 'apple' | 'google' | 'manual'

export interface Subscription {
  id: string
  user_id: string
  plan: SubPlan
  status: SubStatus
  channel: SubChannel
  stripe_subscription_id: string | null
  stripe_customer_id: string | null
  apple_original_transaction_id: string | null
  google_purchase_token: string | null
  trial_start_at: string | null
  trial_end_at: string | null
  current_period_start: string | null
  current_period_end: string | null
  canceled_at: string | null
  grace_period_end_at: string | null
  price_amount: number | null
  currency: string
  coupon_code: string | null
  created_at: string
  updated_at: string
}

// ─────────────────────────────────────────────────────────────
// Reports (spec §15, §16)
// ─────────────────────────────────────────────────────────────

export type ReportStatus = 'open' | 'reviewing' | 'resolved' | 'dismissed'
export type ReportType   = 'spam' | 'spoiler' | 'offensive' | 'harassment' | 'other'

export interface Report {
  id: string
  reporter_id: string
  target_user_id: string | null
  target_type: string
  target_id: string
  type: ReportType
  reason: string | null
  status: ReportStatus
  resolved_by: string | null
  resolution: string | null
  created_at: string
  updated_at: string
}

// ─────────────────────────────────────────────────────────────
// Audit Logs (spec §10: imutável)
// ─────────────────────────────────────────────────────────────

export interface AuditLog {
  id: string
  actor_id: string | null
  target_id: string | null
  action: string
  metadata: Record<string, unknown>
  ip_address: string | null
  user_agent: string | null
  created_at: string
}

/** Todas as ações de auditoria da spec §10 */
export type AuditAction =
  // Usuário
  | 'user.login'
  | 'user.logout'
  | 'user.password_changed'
  | 'user.mfa_enabled'
  | 'user.account_deleted'
  | 'user.data_exported'
  | 'review.created'
  | 'review.deleted'
  | 'note.created'
  | 'note.deleted'
  // Admin
  | 'admin.user_suspended'
  | 'admin.user_banned'
  | 'admin.plan_changed'
  | 'admin.refund_issued'
  | 'admin.feature_flag_toggled'
  | 'club.owner_transferred'
  | 'club.deleted'
  | 'report.resolved'
  | 'payment.approved'
  | 'payment.failed'
  | 'payment.webhook_error'

// ─────────────────────────────────────────────────────────────
// Invites (spec §15)
// ─────────────────────────────────────────────────────────────

export type InviteType   = 'early_access' | 'beta' | 'gift'
export type InviteStatus = 'pending' | 'used' | 'expired' | 'revoked'

export interface Invite {
  id: string
  code: string
  type: InviteType
  status: InviteStatus
  email: string | null
  used_by: string | null
  used_at: string | null
  expires_at: string | null
  created_by: string | null
  max_uses: number
  use_count: number
  notes: string | null
  created_at: string
}

// ─────────────────────────────────────────────────────────────
// LGPD Requests (spec §11)
// ─────────────────────────────────────────────────────────────

export type LGPDType   = 'deletion' | 'export'
export type LGPDStatus = 'pending' | 'processing' | 'completed' | 'failed'

export interface LGPDRequest {
  id: string
  user_id: string
  type: LGPDType
  status: LGPDStatus
  requested_at: string
  deadline_at: string
  processed_at: string | null
  processed_by: string | null
  notes: string | null
  export_url: string | null
}

// ─────────────────────────────────────────────────────────────
// Book Lists (spec §12: listas públicas indexadas)
// ─────────────────────────────────────────────────────────────

export type ListVisibility = 'public' | 'friends' | 'private'

export interface BookList {
  id: string
  user_id: string
  title: string
  description: string | null
  cover_url: string | null
  visibility: ListVisibility
  created_at: string
  updated_at: string
}

// ─────────────────────────────────────────────────────────────
// Notification Platform (spec §4)
// ─────────────────────────────────────────────────────────────

/** Canais de entrega de notificações. */
export type NotificationChannel = 'push' | 'email' | 'inbox' | 'web'

/** Eventos canônicos que disparam notificações. */
export type NotificationEvent =
  | 'newFollower'
  | 'newComment'
  | 'clubInvite'
  | 'checkIn'
  | 'challenge'
  | 'newBook'
  | 'clubUpdate'
  | 'billing'
  | 'system'

/** Registro de notificação na inbox do usuário. */
export interface Notification {
  id: string
  user_id: string
  event: NotificationEvent
  title: string
  body: string
  data: Record<string, string>
  read: boolean
  created_at: string
}

/** Preferência por evento/canal do usuário. */
export interface NotificationPreference {
  id: string
  user_id: string
  event: NotificationEvent
  channel: NotificationChannel
  enabled: boolean
  updated_at: string
}

// ─────────────────────────────────────────────────────────────
// Queue Platform (spec §5)
// ─────────────────────────────────────────────────────────────

/** Filas canônicas — espelham QueueNames no Flutter. */
export type QueueName =
  | 'queue:email'
  | 'queue:push'
  | 'queue:google_books'
  | 'queue:analytics'
  | 'queue:reviews'
  | 'queue:billing'
  | 'queue:lgpd'
  | 'queue:recommendations'
  | 'queue:media'
  | 'queue:ai'

export type QueueJobStatus = 'pending' | 'running' | 'done' | 'failed' | 'dead_letter'

export interface QueueJob {
  id: string
  queue: QueueName
  payload: Record<string, unknown>
  status: QueueJobStatus
  attempts: number
  max_retries: number
  error: string | null
  created_at: string
  started_at: string | null
  completed_at: string | null
}

// ─────────────────────────────────────────────────────────────
// Media Pipeline (spec §8)
// ─────────────────────────────────────────────────────────────

export type MediaType = 'avatar' | 'cover' | 'club_cover' | 'attachment'
export type MediaStatus = 'pending' | 'processing' | 'ready' | 'failed'

export interface MediaAsset {
  id: string
  user_id: string
  type: MediaType
  original_url: string
  processed_url: string | null
  thumbnail_url: string | null
  status: MediaStatus
  mime_type: string
  size_bytes: number
  width: number | null
  height: number | null
  created_at: string
  updated_at: string
}

export interface BookListItem {
  id: string
  list_id: string
  book_catalog_id: string
  position: number
  note: string | null
  added_at: string
}

// ─────────────────────────────────────────────────────────────
// Feature Flags (spec §19)
// ─────────────────────────────────────────────────────────────

export interface FeatureFlag {
  id: string
  key: string
  description: string
  enabled: boolean
  rollout_percent: number       // 0–100
  target_roles: string[]
  target_user_ids: string[]
  created_at: string
  updated_at: string
}
