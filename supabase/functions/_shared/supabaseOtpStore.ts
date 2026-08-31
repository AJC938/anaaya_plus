// SMS-03 — the real, Postgres-backed `OtpStore` implementation (see
// otpStore.ts for the interface and all the actual security/business
// logic — this file is pure I/O plumbing, deliberately thin so the logic
// it serves stays testable without a real database, exactly like
// `firestoreAdmin.ts` keeps `paymentLogic.ts` free of any HTTP concern).
//
// Uses `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` — both injected
// automatically into every deployed Supabase Edge Function by the
// platform itself, never manually configured, never logged. The
// service-role key deliberately bypasses this table's Row Level Security
// (which has no policies at all — see the migration's own comment) so
// only server-side code (this module) can ever read or write OTP
// challenges; no Supabase Auth, no anon/authenticated client role is
// introduced anywhere in this flow.
import { createClient } from "npm:@supabase/supabase-js@2";
import type { OtpChallengeRow, OtpStore } from "./otpStore.ts";

interface OtpChallengeTableRow {
  id: string;
  phone: string;
  otp_hash: string;
  salt: string;
  attempts: number;
  max_attempts: number;
  expires_at: string;
  created_at: string;
  consumed_at: string | null;
}

function fromTableRow(row: OtpChallengeTableRow): OtpChallengeRow {
  return {
    id: row.id,
    phone: row.phone,
    otpHash: row.otp_hash,
    salt: row.salt,
    attempts: row.attempts,
    maxAttempts: row.max_attempts,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    consumedAt: row.consumed_at,
  };
}

let client: ReturnType<typeof createClient> | null = null;
function getClient() {
  if (client) return client;
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) throw new Error("SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY are not configured");
  client = createClient(url, serviceRoleKey);
  return client;
}

export class SupabaseOtpStore implements OtpStore {
  async findActiveByPhone(phone: string): Promise<OtpChallengeRow | null> {
    const { data, error } = await getClient()
      .from("otp_challenges")
      .select("*")
      .eq("phone", phone)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw new Error(`otp_challenges lookup failed: ${error.message}`);
    return data ? fromTableRow(data as OtpChallengeTableRow) : null;
  }

  async countCreatedSince(phone: string, sinceIso: string): Promise<number> {
    const { count, error } = await getClient()
      .from("otp_challenges")
      .select("id", { count: "exact", head: true })
      .eq("phone", phone)
      .gte("created_at", sinceIso);
    if (error) throw new Error(`otp_challenges count failed: ${error.message}`);
    return count ?? 0;
  }

  async insert(row: Omit<OtpChallengeRow, "id">): Promise<OtpChallengeRow> {
    const { data, error } = await getClient()
      .from("otp_challenges")
      .insert({
        phone: row.phone,
        otp_hash: row.otpHash,
        salt: row.salt,
        attempts: row.attempts,
        max_attempts: row.maxAttempts,
        expires_at: row.expiresAt,
        created_at: row.createdAt,
        consumed_at: row.consumedAt,
      })
      .select()
      .single();
    if (error) throw new Error(`otp_challenges insert failed: ${error.message}`);
    return fromTableRow(data as OtpChallengeTableRow);
  }

  async incrementAttempts(id: string): Promise<void> {
    const { error } = await getClient().rpc("increment_otp_attempts", { challenge_id: id });
    if (error) throw new Error(`otp_challenges attempt increment failed: ${error.message}`);
  }

  async consume(id: string): Promise<void> {
    const { error } = await getClient()
      .from("otp_challenges")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", id);
    if (error) throw new Error(`otp_challenges consume failed: ${error.message}`);
  }
}
