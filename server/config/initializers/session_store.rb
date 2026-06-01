# Long-lived signed session cookie — Ike never auto-logs you out. Manual
# "Sign out" still works, but otherwise the cookie persists for a year and
# refreshes itself as you use the app.
Rails.application.config.session_store :cookie_store,
                                       key: "_ike_session",
                                       expire_after: 1.year
