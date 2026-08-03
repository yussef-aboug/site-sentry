<?php
/**
 * Plugin Name: SiteSentry Hardening
 * Description: Conservative, reversible hardening applied by SiteSentry. Every change is
 *              gated by a flag below. To roll back COMPLETELY, delete this one file.
 * Version:     1.0
 * Author:      SiteSentry
 *
 * WHY A MU-PLUGIN, NOT functions.php:
 *   - mu-plugins load unconditionally and survive theme switches and theme updates.
 *   - functions.php belongs to the theme; an update or a theme change silently wipes it.
 *   - Rollback here is one file deletion, with no database state to unwind.
 *
 * INSTALL:  wp-content/mu-plugins/sitesentry-hardening.php   (create mu-plugins/ if absent)
 * ROLLBACK: delete the file. Nothing else to undo.
 *
 * Each flag maps to a finding from scripts/prospect-scan.sh. Turn on ONLY what the scan
 * actually flagged, one at a time, verifying between each.
 */

if (!defined('ABSPATH')) { exit; }

/* -------------------------------------------------------------------------
 * FLAGS - default to the changes that are safe on essentially any site.
 * ---------------------------------------------------------------------- */
define('SITESENTRY_HIDE_VERSION',   true);   // remove the WordPress version from public output
define('SITESENTRY_NOSNIFF',        true);   // X-Content-Type-Options: nosniff
define('SITESENTRY_FRAME_OPTIONS',  true);   // X-Frame-Options: SAMEORIGIN
define('SITESENTRY_REFERRER',       true);   // Referrer-Policy: strict-origin-when-cross-origin
define('SITESENTRY_DISABLE_XMLRPC', false);  // see the warning below before enabling
define('SITESENTRY_HSTS',           false);  // DANGEROUS OUT OF ORDER - read the block below
define('SITESENTRY_CSP',            false);  // CAN WHITE-SCREEN THE SITE - read the block below

/* -------------------------------------------------------------------------
 * 1. Hide the WordPress version
 *    Stops <meta name="generator" content="WordPress 6.x"> and the ?ver= query
 *    strings that leak the same number through script/style URLs.
 * ---------------------------------------------------------------------- */
if (SITESENTRY_HIDE_VERSION) {
    remove_action('wp_head', 'wp_generator');
    add_filter('the_generator', '__return_empty_string');
    add_filter('style_loader_src',  'sitesentry_strip_core_ver', 9999);
    add_filter('script_loader_src', 'sitesentry_strip_core_ver', 9999);
    function sitesentry_strip_core_ver($src) {
        // Only strip the version when it equals the CORE version - plugin/theme asset
        // versions are cache-busters, and removing those breaks cache invalidation.
        if (strpos($src, 'ver=' . get_bloginfo('version')) !== false) {
            $src = remove_query_arg('ver', $src);
        }
        return $src;
    }
}

/* -------------------------------------------------------------------------
 * 2. Security headers
 *    send_headers fires before any output, so header() is safe here.
 * ---------------------------------------------------------------------- */
add_action('send_headers', function () {
    if (SITESENTRY_NOSNIFF)       { header('X-Content-Type-Options: nosniff'); }
    if (SITESENTRY_FRAME_OPTIONS) { header('X-Frame-Options: SAMEORIGIN'); }
    if (SITESENTRY_REFERRER)      { header('Referrer-Policy: strict-origin-when-cross-origin'); }

    /* HSTS - ORDER MATTERS, AND GETTING IT WRONG CAUSES AN OUTAGE.
     * This tells browsers to REFUSE http:// for this domain for max-age seconds,
     * cached client-side, with no click-through for the visitor. If HTTPS is not
     * already reliably enforced, or the certificate later lapses, visitors are hard
     * blocked and you cannot undo it from the server - their browser has already
     * cached the instruction.
     * ONLY enable after: http:// reliably redirects to https://, the certificate is
     * valid, and auto-renewal is confirmed working. Start at 300 (5 minutes), verify
     * the site still loads, then raise. Do not add "preload" - that is effectively
     * irreversible. */
    if (SITESENTRY_HSTS && is_ssl()) {
        header('Strict-Transport-Security: max-age=300');
    }

    /* CSP - CAN VISUALLY OR FUNCTIONALLY BREAK THE SITE.
     * WordPress themes, page builders (Elementor, Divi) and many plugins emit inline
     * <script> and <style>. A policy without 'unsafe-inline' blocks them and the page
     * renders unstyled or half-broken - often only on SOME templates, so a homepage
     * spot-check will not catch it.
     * Never enable this on production without testing every critical page on staging
     * first, and start in Report-Only mode (below) so nothing is actually blocked. */
    if (SITESENTRY_CSP && !is_admin()) {
        header("Content-Security-Policy-Report-Only: default-src 'self'; "
             . "img-src 'self' data: https:; "
             . "style-src 'self' 'unsafe-inline'; "
             . "script-src 'self' 'unsafe-inline'; "
             . "frame-ancestors 'self'");
    }
}, 1);

/* -------------------------------------------------------------------------
 * 3. XML-RPC
 *    WARNING - this BREAKS: the WordPress mobile app, Jetpack, some backup and
 *    migration plugins, and any remote publishing tool the client uses. ASK the
 *    client before enabling. If they use none of the above it is safe.
 *
 *    HONEST LIMIT: this disables the XML-RPC *methods*, but wp-content's xmlrpc.php
 *    still exists and still answers requests, so an external scan may STILL report
 *    "xmlrpc.php is open". Fully blocking it requires a server rule (nginx/Apache) or
 *    a WAF, which is the host's territory, not WordPress's.
 * ---------------------------------------------------------------------- */
if (SITESENTRY_DISABLE_XMLRPC) {
    add_filter('xmlrpc_enabled', '__return_false');
    add_filter('xmlrpc_methods', function () { return []; });
    // Also drop the advertising header/link so we stop pointing at it.
    add_filter('wp_headers', function ($headers) { unset($headers['X-Pingback']); return $headers; });
    remove_action('wp_head', 'rsd_link');
}
