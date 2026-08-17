import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: "https://rtvizpsfvtjowbimugns.supabase.co")!
    static let supabaseAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0dml6cHNmdnRqb3diaW11Z25zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNjMyMTksImV4cCI6MjEwMTgzOTIxOX0.e25DgGY5UraIRIqKq15e7aJji-7cwhcl7mEiixMmV64"
    static let appOrigin = URL(string: "https://yahpz.com")!
    static let passwordResetRedirect = URL(string: "https://yahpz.com/?set_password=1")!
}
