<?php
// forgot_password.php - Send reset password link with SendGrid

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'db_config.php';

function sanitize($data) {
    return htmlspecialchars(trim(stripslashes($data)));
}

function generateResetToken() {
    return bin2hex(random_bytes(32));
}

function sendEmailViaSendGrid($to, $toName, $subject, $body, $fromEmail, $fromName, $apiKey) {
    $data = [
        'personalizations' => [[
            'to' => [['email' => $to, 'name' => $toName]],
            'subject' => $subject
        ]],
        'from' => ['email' => $fromEmail, 'name' => $fromName],
        'content' => [[
            'type' => 'text/plain',
            'value' => $body
        ]]
    ];
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://api.sendgrid.com/v3/mail/send');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $apiKey,
        'Content-Type: application/json'
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return $httpCode === 202; // SendGrid success code
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Invalid request method.']);
    exit;
}

$json_data = file_get_contents('php://input');
$data = json_decode($json_data, true);

if (!isset($data['email']) || empty($data['email'])) {
    echo json_encode(['success' => false, 'message' => 'Email is required.']);
    exit;
}

$email = sanitize($data['email']);

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(['success' => false, 'message' => 'Invalid email format.']);
    exit;
}

try {
    $conn = getConnection();
    
    // Cek apakah email ada di database
    $stmt = $conn->prepare("SELECT id, username FROM users WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode(['success' => false, 'message' => 'Email not found in our records.']);
        exit;
    }
    
    $user = $result->fetch_assoc();
    $userId = $user['id'];
    $username = $user['username'];
    
    // Generate reset token
    $resetToken = generateResetToken();
    
    // Set timezone Indonesia
    date_default_timezone_set('Asia/Jakarta');
    $expiresAt = date('Y-m-d H:i:s', strtotime('+24 hours'));  // 24 jam dari sekarang
    
    // Update user dengan token reset
    $stmt = $conn->prepare("UPDATE users SET reset_token = ?, reset_token_expires = ? WHERE id = ?");
    $stmt->bind_param("ssi", $resetToken, $expiresAt, $userId);
    $stmt->execute();
    
    // Debug log
    $logFile = __DIR__ . '/debug_tokens.txt';
    $logContent = "\n=== TOKEN GENERATED ===\n";
    $logContent .= "User ID: $userId\n";
    $logContent .= "Email: $email\n";
    $logContent .= "Token: $resetToken\n";
    $logContent .= "Expires: $expiresAt\n";
    $logContent .= "Time: " . date('Y-m-d H:i:s') . "\n";
    $logContent .= "======================\n";
    
    file_put_contents($logFile, $logContent, FILE_APPEND);
    
    // Buat reset link
    $resetLink = "http://192.168.56.1/wefarm/lib/reset_password.php?token=" . $resetToken;
    
    $subject = "Password Reset Request - WeFarm";
    $message = "
Hello $username,

You have requested to reset your password for your WeFarm account.

Please click the link below to reset your password:
$resetLink

This link will expire in 1 hour for security reasons.

If you did not request this reset, please ignore this email.

Best regards,
WeFarm Team
    ";
    
    // SendGrid Configuration
    $sendGridApiKey = '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';  // GANTI dengan API Key kamu
    $fromEmail = 'wefarmapp2025@gmail.com';             // GANTI dengan email verified kamu
    $fromName = 'WeFarm';
    
    // Kirim email via SendGrid
    $emailSent = sendEmailViaSendGrid(
        $email,          // To
        $username,       // To Name
        $subject,        // Subject
        $message,        // Body
        $fromEmail,      // From Email
        $fromName,       // From Name
        $sendGridApiKey  // API Key
    );
    
    if ($emailSent) {
        echo json_encode([
            'success' => true,
            'message' => 'Password reset link has been sent to your email.'
        ]);
    } else {
        // Fallback: log ke file untuk debugging
        $logFile = __DIR__ . '/reset_emails.txt';
        $logContent = "\n=== SENDGRID ERROR ===\n";
        $logContent .= "To: $email\n";
        $logContent .= "User: $username\n";
        $logContent .= "Reset Link: $resetLink\n";
        $logContent .= "Time: " . date('Y-m-d H:i:s') . "\n";
        $logContent .= "====================\n";
        
        file_put_contents($logFile, $logContent, FILE_APPEND);
        
        echo json_encode([
            'success' => false,
            'message' => 'Failed to send email. Please try again later.'
        ]);
    }
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>