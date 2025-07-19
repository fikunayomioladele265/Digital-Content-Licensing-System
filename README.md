# Digital Content Licensing System

A comprehensive blockchain-based system for managing digital content licensing, built on the Stacks blockchain using Clarity smart contracts.

## Overview

This system provides a complete solution for digital content creators, platforms, and consumers to manage licensing, revenue sharing, and piracy detection in a decentralized manner.

## System Components

### 1. Content Registration Contract (`content-registry.clar`)
- Records creative work ownership and metadata
- Establishes proof of creation and ownership
- Manages content categorization and tagging

### 2. Usage Permission Contract (`usage-permissions.clar`)
- Manages licensing terms and restrictions
- Defines usage rights and limitations
- Handles permission granting and revocation

### 3. Revenue Sharing Contract (`revenue-sharing.clar`)
- Distributes earnings between creators and platforms
- Manages royalty calculations and payments
- Tracks revenue streams and distributions

### 4. Piracy Detection Contract (`piracy-detection.clar`)
- Monitors unauthorized content usage
- Records violation reports and evidence
- Manages dispute resolution processes

### 5. Expiration Management Contract (`expiration-management.clar`)
- Handles license renewal and termination
- Manages subscription-based licensing
- Automates license status updates

## Key Features

- **Decentralized Ownership**: Immutable proof of content ownership
- **Flexible Licensing**: Support for various licensing models
- **Automated Revenue**: Smart contract-based revenue distribution
- **Piracy Protection**: Community-driven violation reporting
- **License Management**: Automated expiration and renewal handling

## Data Structures

### Content Registration
- Content ID (unique identifier)
- Creator principal
- Content hash (for integrity verification)
- Creation timestamp
- Category and tags
- License terms reference

### Usage Permissions
- Permission ID
- Content reference
- Licensee principal
- Usage type and restrictions
- Duration and expiration
- Fee structure

### Revenue Sharing
- Revenue pool per content
- Creator share percentage
- Platform share percentage
- Distribution history
- Pending payments

## Getting Started

1. Deploy contracts to Stacks blockchain
2. Register content using the content registry
3. Set up licensing terms via usage permissions
4. Configure revenue sharing parameters
5. Enable piracy detection monitoring
6. Manage license lifecycles

## Testing

Run the test suite using:
\`\`\`bash
npm test
\`\`\`

## License

This project is licensed under the MIT License.
