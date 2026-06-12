# Karpenter Interruption Queue
#
# SQS queue + EventBridge rule that notify Karpenter of EC2 spot interruption
# warnings, rebalance recommendations, and instance state-change events
# (terminated/stopping), so Karpenter can gracefully drain and replace nodes
# before they disappear.


# Queue Karpenter polls for interruption/rebalance events
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${aws_eks_cluster.main_cluster.name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

# Allows EventBridge to deliver matched events to the queue, restricted to
# events from this specific rule
resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn

        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.karpenter_node_events.arn
          }
        }
      }
    ]
  })
}

# Matches spot interruption warnings, rebalance recommendations, and
# instance termination/stopping state changes
resource "aws_cloudwatch_event_rule" "karpenter_node_events" {
  name        = "${aws_eks_cluster.main_cluster.name}-karpenter-node-events"
  description = "Karpenter node interruption events"

  event_pattern = jsonencode({
    source = ["aws.ec2"],
    "detail-type" = [
      "EC2 Spot Instance Interruption Warning",
      "EC2 Instance Rebalance Recommendation",
      "EC2 Instance State-change Notification"
    ],
    detail = {
      state = ["terminated", "stopping"]
    }
  })
}

# Routes matched events to the interruption queue
resource "aws_cloudwatch_event_target" "karpenter_node_events" {
  rule = aws_cloudwatch_event_rule.karpenter_node_events.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}