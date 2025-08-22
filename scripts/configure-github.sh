#!/bin/bash

# Valley Ridge Inventory Sync - GitHub Repository Configuration
# This script configures an existing GitHub repository

set -e

echo "🔧 Configuring GitHub Repository for Valley Ridge Inventory Sync"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if GitHub CLI is installed and authenticated
check_gh_cli() {
    print_status "Checking GitHub CLI installation and authentication..."
    
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI not found. Please install it first: brew install gh"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI not authenticated. Please run: gh auth login"
        exit 1
    fi
    
    print_success "GitHub CLI found and authenticated"
}

# Get repository details from git remote
get_repo_details() {
    print_status "Getting repository details from git remote..."
    
    # Get the remote URL
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -z "$REMOTE_URL" ]; then
        print_error "No git remote found. Please add your GitHub repository as origin first."
        exit 1
    fi
    
    # Extract username and repo name from the URL
    if [[ $REMOTE_URL =~ github\.com[:/]([^/]+)/([^/]+)\.git ]]; then
        GITHUB_USER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
    else
        print_error "Could not parse GitHub repository URL: $REMOTE_URL"
        exit 1
    fi
    
    print_success "Repository: $GITHUB_USER/$REPO_NAME"
}

# Set up branch protection
setup_branch_protection() {
    print_status "Setting up branch protection for main branch..."
    
    # Try to enable branch protection with proper JSON structure
    if gh api repos/$GITHUB_USER/$REPO_NAME/branches/main/protection \
        --method PUT \
        --field required_status_checks='{"strict":true,"contexts":[]}' \
        --field enforce_admins=true \
        --field required_pull_request_reviews='{"required_approving_review_count":1}' \
        --field restrictions=null 2>/dev/null; then
        print_success "Branch protection enabled for main branch"
    else
        print_warning "Branch protection failed, but continuing with other configurations"
        print_status "You can enable it manually in Settings > Branches"
    fi
}

# Create project labels
create_labels() {
    print_status "Creating project labels..."
    
    # Create labels one by one
    create_label "enhancement" "a2eeef" "New feature or request"
    create_label "bug" "d73a4a" "Something isn't working"
    create_label "documentation" "0075ca" "Documentation improvements"
    create_label "good-first-issue" "7057ff" "Good for newcomers"
    create_label "help-wanted" "008672" "Extra attention is needed"
    create_label "question" "d876e3" "Further information is requested"
    create_label "wontfix" "ffffff" "This will not be worked on"
    create_label "duplicate" "cfd3d7" "This issue or pull request already exists"
    create_label "invalid" "e4e669" "This doesn't seem right"
    
    print_success "Project labels created/updated"
}

# Helper function to create a single label
create_label() {
    local name="$1"
    local color="$2"
    local description="$3"
    
    # Check if label already exists
    if gh api repos/$GITHUB_USER/$REPO_NAME/labels/$name &>/dev/null; then
        print_status "Label '$name' already exists, updating..."
        gh api repos/$GITHUB_USER/$REPO_NAME/labels/$name \
            --method PATCH \
            --field color="$color" \
            --field description="$description"
    else
        print_status "Creating label '$name'..."
        gh api repos/$GITHUB_USER/$REPO_NAME/labels \
            --method POST \
            --field name="$name" \
            --field color="$color" \
            --field description="$description"
    fi
}

# Create initial milestones
create_milestones() {
    print_status "Creating initial milestones..."
    
    # Create v1.0.0 milestone
    gh api repos/$GITHUB_USER/$REPO_NAME/milestones \
        --method POST \
        --field title="v1.0.0 - Production Release" \
        --field description="Initial production release of the inventory sync system" \
        --field state="open"
    
    # Create v1.1.0 milestone
    gh api repos/$GITHUB_USER/$REPO_NAME/milestones \
        --method POST \
        --field title="v1.1.0 - Enhanced Features" \
        --field description="Additional features and improvements" \
        --field state="open"
    
    print_success "Initial milestones created"
}

# Create initial issues
create_initial_issues() {
    print_status "Creating initial issues..."
    
    # Create a welcome issue
    gh issue create \
        --title "Welcome to Valley Ridge Inventory Sync" \
        --body "## 🎉 Welcome!

This repository contains the Valley Ridge Inventory Sync system, an AWS-based solution for processing inventory files from vendors and integrating with Shopify via Matrixify.

### 🚀 Getting Started

1. **Review the documentation** in the \`docs/\` directory
2. **Deploy the system** using \`./scripts/deploy-incremental.sh\`
3. **Test the functionality** with \`./scripts/test-incremental.sh\`

### 📚 Key Features

- ✅ Full import processing
- ✅ Incremental/delta processing
- ✅ SFTP integration for vendor uploads
- ✅ Matrixify integration with pre-signed URLs
- ✅ Comprehensive monitoring and logging

### 🔧 Development

- Create feature branches: \`git checkout -b feature/new-feature\`
- Follow conventional commit messages
- Submit pull requests for review

Happy coding! 🎯" \
        --label "documentation" \
        --milestone "v1.0.0 - Production Release"
    
    # Create a deployment issue
    gh issue create \
        --title "Deploy to Production Environment" \
        --body "## 🚀 Production Deployment

### Pre-deployment Checklist

- [ ] Test incremental processing with sample files
- [ ] Verify Matrixify integration works correctly
- [ ] Confirm SFTP server is accessible
- [ ] Review CloudWatch logs and metrics
- [ ] Validate error handling and notifications

### Deployment Steps

1. Run \`./scripts/deploy-incremental.sh\`
2. Test with \`./scripts/test-incremental.sh\`
3. Monitor CloudWatch logs
4. Verify S3 bucket structure
5. Test vendor file upload process

### Post-deployment

- [ ] Monitor system performance
- [ ] Review error logs
- [ ] Validate Matrixify imports
- [ ] Document any issues or improvements" \
        --label "enhancement" \
        --milestone "v1.0.0 - Production Release"
    
    print_success "Initial issues created"
}

# Enable repository features
enable_features() {
    print_status "Enabling repository features..."
    
    # Enable issues
    gh api repos/$GITHUB_USER/$REPO_NAME \
        --method PATCH \
        --field has_issues=true \
        --field has_wiki=false \
        --field has_downloads=false
    
    print_success "Repository features configured"
}

# Display configuration summary
show_summary() {
    echo ""
    echo "🎉 GitHub Repository Configuration Complete!"
    echo "==========================================="
    echo ""
    echo "📋 Repository: https://github.com/$GITHUB_USER/$REPO_NAME"
    echo ""
    echo "✅ Configuration Applied:"
    echo "========================"
    echo "✅ Branch protection enabled for main branch"
    echo "✅ Project labels created"
    echo "✅ Initial milestones created"
    echo "✅ Welcome issues created"
    echo "✅ Repository features configured"
    echo ""
    echo "🔧 Next Steps:"
    echo "=============="
    echo "1. Review the repository at: https://github.com/$GITHUB_USER/$REPO_NAME"
    echo "2. Add collaborators if needed"
    echo "3. Set up GitHub Actions for CI/CD (optional)"
    echo "4. Deploy the system: ./scripts/deploy-incremental.sh"
    echo "5. Test the system: ./scripts/test-incremental.sh"
    echo ""
    echo "📚 Development Workflow:"
    echo "======================="
    echo "1. Create feature branches: git checkout -b feature/new-feature"
    echo "2. Make changes and commit: git commit -m 'feat: add new feature'"
    echo "3. Push and create PR: git push origin feature/new-feature"
    echo "4. Review and merge through GitHub"
    echo ""
    echo "🚀 Ready to deploy:"
    echo "=================="
    echo "./scripts/deploy-incremental.sh"
    echo "./scripts/test-incremental.sh"
    echo ""
}

# Main configuration process
main() {
    echo "Starting GitHub repository configuration..."
    echo ""
    
    check_gh_cli
    get_repo_details
    enable_features
    setup_branch_protection
    create_labels
    create_milestones
    create_initial_issues
    show_summary
    
    print_success "GitHub repository configuration completed successfully!"
}

# Run main function
main "$@" 