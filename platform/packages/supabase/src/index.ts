/**
 * @lumen/supabase — clientes compartilhados
 *
 * Re-exporta server.ts e browser.ts para que cada app
 * importe diretamente de '@lumen/supabase/server' ou '@lumen/supabase/browser'.
 */

export { createServerSupabase } from './server'
export { createBrowserSupabase } from './browser'
