
<?php
declare(strict_types=1);

/*
 * License Management System
 * Compatible with PHP 7.4+
 *
 * Set production credentials before deployment.
 * Keep this file outside public access where possible.
 */

if (!defined('APP_BOOTSTRAPPED')) {
    define('APP_BOOTSTRAPPED', true);
}

define('APP_NAME', 'AK License Manager');
define('APP_VERSION', '1.0.0');
define('APP_TIMEZONE', 'UTC');

/*
 * Database configuration.
 * Replace these values with your hosting provider's credentials.
 */
define('DB_HOST', 'localhost');
define('DB_NAME', 'your_database');
define('DB_USER', 'your_db_user');
define('DB_PASS', 'replace_with_database_password');
define('DB_CHARSET', 'utf8mb4');

/*
 * Generate a secret using:
 * php -r "echo bin2hex(random_bytes(32)), PHP_EOL;"
 *
 * Never commit the real secret to a public repository.
 */
define('CLIENT_SECRET', 'REPLACE_WITH_A_RANDOM_64_CHAR_HEX_SECRET');

/*
 * Authentication settings.
 */
define('SESSION_TTL', 86400);
define('REQUEST_TOLERANCE', 300);
define('RATE_LIMIT_MAX', 5);
define('RATE_LIMIT_WINDOW', 60);
define('BCRYPT_COST', 12);

/*
 * Online status is based on the most recent heartbeat.
 */
define('ONLINE_WINDOW', 300);

/*
 * Set true only when HTTPS is correctly configured.
 * Local HTTP development can use false.
 */
define('COOKIE_SECURE', true);

/*
 * Native PHP session configuration.
 */
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.use_strict_mode', '1');
    ini_set('session.use_only_cookies', '1');

    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'domain' => '',
        'secure' => COOKIE_SECURE,
        'httponly' => true,
        'samesite' => 'Strict'
    ]);

    session_start();
}

date_default_timezone_set(APP_TIMEZONE);

/**
 * Return a shared MySQLi connection.
 */
function db(): mysqli
{
    static $connection = null;

    if ($connection instanceof mysqli) {
        return $connection;
    }

    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

    try {
        $connection = new mysqli(
            DB_HOST,
            DB_USER,
            DB_PASS,
            DB_NAME
        );

        $connection->set_charset(DB_CHARSET);

        return $connection;
    } catch (Throwable $e) {
        error_log(
            '[' . gmdate('c') . '] Database connection failed: ' .
            $e->getMessage()
        );

        throw new RuntimeException('Database unavailable.');
    }
}

/**
 * Escape text before placing it into HTML.
 */
function h($value): string
{
    return htmlspecialchars(
        (string) $value,
        ENT_QUOTES | ENT_SUBSTITUTE,
        'UTF-8'
    );
}

/**
 * Send a JSON response and terminate the request.
 */
function json_response(
    array $body,
    int $httpStatus = 200
): void {
    http_response_code($httpStatus);

    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store, private');
    header('X-Content-Type-Options: nosniff');

    echo json_encode(
        $body,
        JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
    );

    exit;
}

/**
 * Read a JSON or form-encoded request body.
 */
function request_data(): array
{
    $contentType = isset($_SERVER['CONTENT_TYPE'])
        ? strtolower(trim(explode(
            ';',
            $_SERVER['CONTENT_TYPE']
        )[0]))
        : '';

    if ($contentType === 'application/json') {
        $raw = file_get_contents('php://input');

        if ($raw === false || $raw === '') {
            json_response([
                'status' => 'error',
                'code' => 'EMPTY_BODY',
                'message' => 'Request body is required.'
            ], 400);
        }

        $data = json_decode($raw, true);

        if (!is_array($data) || json_last_error() !== JSON_ERROR_NONE) {
            json_response([
                'status' => 'error',
                'code' => 'INVALID_JSON',
                'message' => 'Invalid JSON request.'
            ], 400);
        }

        return $data;
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        return $_POST;
    }

    json_response([
        'status' => 'error',
        'code' => 'METHOD_NOT_ALLOWED',
        'message' => 'Use POST for this endpoint.'
    ], 405);

    return [];
}

/**
 * Return the request IP for logging and rate limiting.
 *
 * Do not trust X-Forwarded-For unless the proxy is trusted.
 */
function client_ip(): string
{
    $ip = isset($_SERVER['REMOTE_ADDR'])
        ? $_SERVER['REMOTE_ADDR']
        : '';

    return filter_var($ip, FILTER_VALIDATE_IP)
        ? $ip
        : '0.0.0.0';
}

/**
 * Generate a cryptographically secure license key.
 */
function generate_license_key(): string
{
    return 'AK-' .
        strtoupper(bin2hex(random_bytes(2))) . '-' .
        strtoupper(bin2hex(random_bytes(2))) . '-' .
        strtoupper(bin2hex(random_bytes(2)));
}

/**
 * Create a CSRF token for authenticated admin forms.
 */
function csrf_token(): string
{
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }

    return $_SESSION['csrf_token'];
}

/**
 * Validate a submitted CSRF token.
 */
function verify_csrf($token): bool
{
    return is_string($token)
        && isset($_SESSION['csrf_token'])
        && hash_equals($_SESSION['csrf_token'], $token);
}

/**
 * Create a session token for API clients.
 */
function generate_session_token(): string
{
    return bin2hex(random_bytes(32));
}
