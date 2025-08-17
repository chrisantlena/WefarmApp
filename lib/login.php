<?php
// login.php - User login API (FIXED VERSION)

// Set header to JSON
header('Content-Type: application/json');

// Allow cross-origin requests (CORS)
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// If it's a preflight OPTIONS request, return only the headers and exit
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Include database configuration
require_once 'db_config.php';

// Function to sanitize input data
function sanitize($data) {
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

// Check if the request method is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid request method. Only POST requests are allowed.'
    ]);
    exit;
}

// Get JSON data from the request body
$json_data = file_get_contents('php://input');
$data = json_decode($json_data, true);

// Check if data is valid JSON
if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON data.'
    ]);
    exit;
}

// Check if required fields are present
if (!isset($data['username']) || !isset($data['password']) || empty($data['username']) || empty($data['password'])) {
    echo json_encode([
        'success' => false,
        'message' => 'Username and password are required.'
    ]);
    exit;
}

// Sanitize input data
$username = sanitize($data['username']);
$password = $data['password']; // Don't sanitize password before verification

try {
    // Get database connection
    $conn = getConnection();
    
    // PERBAIKAN: SELECT semua field yang dibutuhkan termasuk name/username
    $stmt = $conn->prepare("SELECT id, username, email, phone, address, password, photo_url FROM users WHERE username = ?");
    $stmt->bind_param("s", $username);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Username atau password salah.'
        ]);
        $stmt->close();
        $conn->close();
        exit;
    }
    
    // Get user data
    $user = $result->fetch_assoc();
    
    // Verify password
    if (password_verify($password, $user['password'])) {
        // Remove password from the response
        unset($user['password']);
        
        // PERBAIKAN UTAMA: Map semua field dengan benar
        $response_user = [
            'id' => $user['id'],
            'name' => $user['username'], // Flutter expect 'name' field
            'username' => $user['username'], // Keep original
            'email' => $user['email'],
            'phone' => $user['phone'],
            'address' => $user['address'],
            // Photo URL dengan semua variasi yang mungkin dibutuhkan
            'photo_url' => $user['photo_url'],
            'photoUrl' => $user['photo_url'],
            'profile_image' => $user['photo_url']
        ];
        
        // Generate a simple API token
        $api_token = bin2hex(random_bytes(32));
        
        // Update user's last login time
        $updateStmt = $conn->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
        $updateStmt->bind_param("i", $user['id']);
        $updateStmt->execute();
        $updateStmt->close();
        
        // DEBUG: Log user data yang dikirim
        error_log("Login response user data: " . json_encode($response_user));
        
        echo json_encode([
            'success' => true,
            'message' => 'Login berhasil!',
            'user' => $response_user,
            'token' => $api_token
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Username atau password salah.'
        ]);
    }
    
    // Close statement and connection
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>