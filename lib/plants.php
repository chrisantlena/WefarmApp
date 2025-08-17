<?php
// Enable error reporting for debugging (disable in production)
error_reporting(0);
ini_set('display_errors', 0);

// Set headers CORS
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept, Cache-Control');
header('Cache-Control: no-cache, no-store, must-revalidate');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

// Include database config
require_once 'db_config.php';

// Function untuk log debugging
function debugLog($message) {
    error_log("[PLANTS API] " . $message);
}

// Function untuk response JSON
function sendResponse($success, $data = null, $message = '', $status_code = 200) {
    http_response_code($status_code);
    $response = [
        'success' => $success,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    if ($data !== null) {
        $response['data'] = $data;
        if (is_array($data)) {
            $response['count'] = count($data);
        }
    }
    
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

try {
    debugLog("Received " . $_SERVER['REQUEST_METHOD'] . " request");
    
    // Get database connection
    $conn = getConnection();
    
    if ($conn->connect_error) {
        throw new Exception("Database connection failed: " . $conn->connect_error);
    }
    
    debugLog("Database connection successful");
    
    // Handle GET request - Retrieve plants
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        debugLog("Processing GET request");
        
        // Check if action parameter exists
        $action = isset($_GET['action']) ? $_GET['action'] : 'list';
        
        switch ($action) {
            case 'test':
                sendResponse(true, ['status' => 'API is working'], 'API connection test successful');
                break;
                
            case 'detail':
                if (!isset($_GET['id'])) {
                    sendResponse(false, null, 'Plant ID is required', 400);
                }
                
                // ✅ INCLUDE PROBLEM_LINKS IN DETAIL QUERY
                $query = "SELECT id, name, duration, image_path, guide, targets, daily_tasks, recommended_products, tutorial_links, problem_links, created_at, updated_at FROM plants WHERE id = ?";
                $stmt = $conn->prepare($query);
                $stmt->bind_param("i", $_GET['id']);
                $stmt->execute();
                $result = $stmt->get_result();
                
                if ($result->num_rows === 0) {
                    sendResponse(false, null, 'Plant not found', 404);
                }
                
                $plant = $result->fetch_assoc();
                
                // Parse JSON fields
                $plant['targets'] = json_decode($plant['targets'], true) ?: [];
                $plant['daily_tasks'] = json_decode($plant['daily_tasks'], true) ?: [];
                $plant['recommended_products'] = json_decode($plant['recommended_products'], true) ?: [];
                $plant['tutorial_links'] = json_decode($plant['tutorial_links'], true) ?: [];
                $plant['problem_links'] = json_decode($plant['problem_links'], true) ?: [];
                
                debugLog("Plant detail loaded with problem_links: " . json_encode($plant['problem_links']));
                
                sendResponse(true, $plant, 'Plant detail retrieved successfully');
                break;
                
            case 'list':
            default:
                // ✅ INCLUDE PROBLEM_LINKS IN LIST QUERY
                $query = "SELECT id, name, duration, image_path, guide, targets, daily_tasks, recommended_products, tutorial_links, problem_links, created_at, updated_at FROM plants ORDER BY id ASC";
                $result = $conn->query($query);
                
                if (!$result) {
                    throw new Exception("Query failed: " . $conn->error);
                }
                
                $plants = [];
                while ($row = $result->fetch_assoc()) {
                    // Parse JSON fields
                    $plant = [
                        'id' => (int)$row['id'],
                        'name' => $row['name'],
                        'duration' => $row['duration'],
                        'image_path' => $row['image_path'],
                        'guide' => $row['guide'],
                        'targets' => json_decode($row['targets'], true) ?: [],
                        'daily_tasks' => json_decode($row['daily_tasks'], true) ?: [],
                        'recommended_products' => json_decode($row['recommended_products'], true) ?: [],
                        'tutorial_links' => json_decode($row['tutorial_links'], true) ?: [],
                        'problem_links' => json_decode($row['problem_links'], true) ?: [],
                        'created_at' => $row['created_at'],
                        'updated_at' => $row['updated_at']
                    ];
                    
                    $plants[] = $plant;
                }
                
                debugLog("Retrieved " . count($plants) . " plants from database");
                sendResponse(true, $plants, 'Plants retrieved successfully');
                break;
        }
    }
    
    // Handle POST request - Add new plant
    else if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        debugLog("Processing POST request");
        
        $json_input = file_get_contents('php://input');
        debugLog("JSON Input: " . $json_input);
        
        if (empty($json_input)) {
            throw new Exception('No data received');
        }
        
        $data = json_decode($json_input, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('Invalid JSON data: ' . json_last_error_msg());
        }
        
        debugLog("Decoded JSON: " . print_r($data, true));
        
        // Single plant insertion with new attributes
        if (!isset($data['name']) || !isset($data['duration'])) {
            throw new Exception('Name and duration are required fields');
        }
        
        $name = trim($data['name']);
        $duration = trim($data['duration']);
        $image_path = isset($data['image_path']) ? trim($data['image_path']) : '';
        $guide = isset($data['guide']) ? trim($data['guide']) : '';
        
        // Process new JSON fields
        $targets = isset($data['targets']) ? json_encode($data['targets']) : json_encode([]);
        $daily_tasks = isset($data['daily_tasks']) ? json_encode($data['daily_tasks']) : json_encode([]);
        $recommended_products = isset($data['recommended_products']) ? json_encode($data['recommended_products']) : json_encode([]);
        $tutorial_links = isset($data['tutorial_links']) ? json_encode($data['tutorial_links']) : json_encode([]);
        $problem_links = isset($data['problem_links']) ? json_encode($data['problem_links']) : json_encode([]);
        
        if (empty($name) || empty($duration)) {
            throw new Exception('Name and duration cannot be empty');
        }
        
        // Check if plant already exists
        $check_stmt = $conn->prepare("SELECT id FROM plants WHERE name = ?");
        $check_stmt->bind_param("s", $name);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();
        
        if ($check_result->num_rows > 0) {
            $check_stmt->close();
            sendResponse(false, null, "Plant '$name' already exists", 409);
        }
        $check_stmt->close();
        
        // ✅ INSERT WITH PROBLEM_LINKS
        $stmt = $conn->prepare("INSERT INTO plants (name, duration, image_path, guide, targets, daily_tasks, recommended_products, tutorial_links, problem_links, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())");
        if (!$stmt) {
            throw new Exception("Prepare statement failed: " . $conn->error);
        }
        
        $stmt->bind_param("sssssssss", $name, $duration, $image_path, $guide, $targets, $daily_tasks, $recommended_products, $tutorial_links, $problem_links);
        
        if ($stmt->execute()) {
            $insert_id = $conn->insert_id;
            debugLog("Successfully inserted plant '$name' with ID: $insert_id");
            
            sendResponse(true, ['id' => $insert_id], "Plant '$name' added successfully");
        } else {
            throw new Exception("Failed to insert plant: " . $stmt->error);
        }
        
        $stmt->close();
    }
    
    // Handle PUT request - Update plant
    else if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        debugLog("Processing PUT request");
        
        $json_input = file_get_contents('php://input');
        $data = json_decode($json_input, true);
        
        if (!isset($data['id'])) {
            throw new Exception('Plant ID is required for update');
        }
        
        $plant_id = $data['id'];
        $updateFields = [];
        $params = [];
        $types = "";
        
        // Check which fields to update
        if (isset($data['name'])) {
            $updateFields[] = "name = ?";
            $params[] = trim($data['name']);
            $types .= "s";
        }
        
        if (isset($data['duration'])) {
            $updateFields[] = "duration = ?";
            $params[] = trim($data['duration']);
            $types .= "s";
        }
        
        if (isset($data['image_path'])) {
            $updateFields[] = "image_path = ?";
            $params[] = trim($data['image_path']);
            $types .= "s";
        }
        
        if (isset($data['guide'])) {
            $updateFields[] = "guide = ?";
            $params[] = trim($data['guide']);
            $types .= "s";
        }
        
        if (isset($data['targets'])) {
            $updateFields[] = "targets = ?";
            $params[] = json_encode($data['targets']);
            $types .= "s";
        }
        
        if (isset($data['daily_tasks'])) {
            $updateFields[] = "daily_tasks = ?";
            $params[] = json_encode($data['daily_tasks']);
            $types .= "s";
        }
        
        if (isset($data['recommended_products'])) {
            $updateFields[] = "recommended_products = ?";
            $params[] = json_encode($data['recommended_products']);
            $types .= "s";
        }
        
        if (isset($data['tutorial_links'])) {
            $updateFields[] = "tutorial_links = ?";
            $params[] = json_encode($data['tutorial_links']);
            $types .= "s";
        }
        
        // ✅ HANDLE PROBLEM_LINKS UPDATE
        if (isset($data['problem_links'])) {
            $updateFields[] = "problem_links = ?";
            $params[] = json_encode($data['problem_links']);
            $types .= "s";
        }
        
        if (empty($updateFields)) {
            throw new Exception('No fields to update');
        }
        
        $updateFields[] = "updated_at = NOW()";
        
        // Add plant_id to params
        $params[] = $plant_id;
        $types .= "i";
        
        $sql = "UPDATE plants SET " . implode(', ', $updateFields) . " WHERE id = ?";
        
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                sendResponse(true, null, "Plant updated successfully");
            } else {
                sendResponse(false, null, "Plant not found or no changes made", 404);
            }
        } else {
            throw new Exception("Failed to update plant: " . $stmt->error);
        }
        
        $stmt->close();
    }
    
    else {
        sendResponse(false, null, 'Method not allowed', 405);
    }
    
} catch (Exception $e) {
    debugLog("Exception: " . $e->getMessage());
    sendResponse(false, null, $e->getMessage(), 500);
    
} finally {
    if (isset($conn) && $conn) {
        $conn->close();
        debugLog("Database connection closed");
    }
}
?>