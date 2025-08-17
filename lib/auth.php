<?php
require_once 'db_config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

function sendResponse($success, $data = null, $message = '', $status_code = 200) {
    http_response_code($status_code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data
    ]);
    exit;
}

try {
    $conn = getConnection();
    
    $data = json_decode(file_get_contents('php://input'), true);
    $action = $data['action'] ?? null;

    if ($action == 'register') {
        // Handle registration
        $username = trim($data['username']);
        $email = trim($data['email']);
        $password = $data['password'];

        // Validation
        if (empty($username) || empty($email) || empty($password)) {
            sendResponse(false, null, 'All fields are required', 400);
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            sendResponse(false, null, 'Invalid email format', 400);
        }

        if (strlen($password) < 6) {
            sendResponse(false, null, 'Password must be at least 6 characters', 400);
        }

        // Check if user exists
        $stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        
        if ($stmt->get_result()->num_rows > 0) {
            sendResponse(false, null, 'Email already registered', 400);
        }

        // Hash password
        $passwordHash = password_hash($password, PASSWORD_BCRYPT);

        // Create new user
        $stmt = $conn->prepare("INSERT INTO users (username, email, password) VALUES (?, ?, ?)");
        $stmt->bind_param("sss", $username, $email, $passwordHash);
        
        if ($stmt->execute()) {
            $userId = $conn->insert_id;
            
            sendResponse(true, [
                'user' => [
                    'id' => $userId,
                    'username' => $username,
                    'email' => $email
                ]
            ], 'Registration successful');
        } else {
            throw new Exception("Registration failed");
        }
    } 
    elseif ($action == 'login') {
        // Handle login
        $email = trim($data['email']);
        $password = $data['password'];

        // Validation
        if (empty($email) || empty($password)) {
            sendResponse(false, null, 'Email and password are required', 400);
        }

        $stmt = $conn->prepare("SELECT id, username, email, password FROM users WHERE email = ?");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 0) {
            sendResponse(false, null, 'Invalid credentials', 401);
        }

        $user = $result->fetch_assoc();
        
        if (!password_verify($password, $user['password'])) {
            sendResponse(false, null, 'Invalid credentials', 401);
        }

        sendResponse(true, [
            'user' => [
                'id' => $user['id'],
                'username' => $user['username'],
                'email' => $user['email']
            ]
        ], 'Login successful');
    } 
    else {
        sendResponse(false, null, 'Invalid action', 400);
    }
} catch (Exception $e) {
    sendResponse(false, null, $e->getMessage(), 500);
}
?>