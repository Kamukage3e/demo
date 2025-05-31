package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type JobResponse struct {
	JobID     string    `json:"job_id"`
	Status    string    `json:"status"`
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
	JobType   string    `json:"job_type"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Received request: %s %s", request.HTTPMethod, request.Path)

	// Add CORS headers
	headers := map[string]string{
		"Content-Type":                 "application/json",
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Headers": "Content-Type",
		"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
	}

	// Handle preflight requests
	if request.HTTPMethod == "OPTIONS" {
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Headers:    headers,
			Body:       "",
		}, nil
	}

	// Route based on path
	switch request.Path {
	case "/health":
		return handleHealth(headers)
	case "/jobs":
		return handleJobs(request, headers)
	case "/jobs/trigger":
		return handleTriggerJob(request, headers)
	default:
		return handleDefault(headers)
	}
}

func handleHealth(headers map[string]string) (events.APIGatewayProxyResponse, error) {
	response := map[string]interface{}{
		"status":      "healthy",
		"service":     "gitops-demo-lambda",
		"environment": os.Getenv("ENVIRONMENT"),
		"timestamp":   time.Now(),
	}

	body, _ := json.Marshal(response)
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers:    headers,
		Body:       string(body),
	}, nil
}

func handleJobs(request events.APIGatewayProxyRequest, headers map[string]string) (events.APIGatewayProxyResponse, error) {
	if request.HTTPMethod != "GET" {
		return methodNotAllowed(headers)
	}

	// Mock job list for demo
	jobs := []JobResponse{
		{
			JobID:     "job-001",
			Status:    "completed",
			Message:   "Database backup completed successfully",
			Timestamp: time.Now().Add(-1 * time.Hour),
			JobType:   "backup",
		},
		{
			JobID:     "job-002",
			Status:    "running",
			Message:   "CI pipeline in progress",
			Timestamp: time.Now().Add(-10 * time.Minute),
			JobType:   "ci",
		},
	}

	body, _ := json.Marshal(map[string]interface{}{
		"jobs":  jobs,
		"count": len(jobs),
	})

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers:    headers,
		Body:       string(body),
	}, nil
}

func handleTriggerJob(request events.APIGatewayProxyRequest, headers map[string]string) (events.APIGatewayProxyResponse, error) {
	if request.HTTPMethod != "POST" {
		return methodNotAllowed(headers)
	}

	// Parse job type from query parameters
	jobType := request.QueryStringParameters["type"]
	if jobType == "" {
		jobType = "default"
	}

	// Generate mock job ID
	jobID := fmt.Sprintf("job-%d", time.Now().Unix())

	response := JobResponse{
		JobID:     jobID,
		Status:    "triggered",
		Message:   fmt.Sprintf("Job of type '%s' has been triggered successfully", jobType),
		Timestamp: time.Now(),
		JobType:   jobType,
	}

	body, _ := json.Marshal(response)
	log.Printf("Triggered job: %s (type: %s)", jobID, jobType)

	return events.APIGatewayProxyResponse{
		StatusCode: 201,
		Headers:    headers,
		Body:       string(body),
	}, nil
}

func handleDefault(headers map[string]string) (events.APIGatewayProxyResponse, error) {
	response := map[string]interface{}{
		"message": "GitOps Demo - Internal Developer Portal API",
		"version": "1.0.0",
		"endpoints": map[string]string{
			"health":      "GET /health",
			"list_jobs":   "GET /jobs",
			"trigger_job": "POST /jobs/trigger?type=<job_type>",
		},
		"timestamp": time.Now(),
	}

	body, _ := json.Marshal(response)
	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Headers:    headers,
		Body:       string(body),
	}, nil
}

func methodNotAllowed(headers map[string]string) (events.APIGatewayProxyResponse, error) {
	errorResp := ErrorResponse{
		Error:   "Method Not Allowed",
		Message: "The requested HTTP method is not supported for this endpoint",
	}

	body, _ := json.Marshal(errorResp)
	return events.APIGatewayProxyResponse{
		StatusCode: 405,
		Headers:    headers,
		Body:       string(body),
	}, nil
}

func main() {
	lambda.Start(handler)
}
