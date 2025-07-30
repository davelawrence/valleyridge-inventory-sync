#!/bin/bash

# Valley Ridge Inventory Sync - GitHub Repository Setup
# This script helps set up the GitHub repository

set -e

echo "🚀 Setting up GitHub Repository for Valley Ridge Inventory Sync"
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

# Check if git is installed
check_git() {
    print_status "Checking Git installation..."
    
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi
    
    print_success "Git found"
}

# Check if GitHub CLI is installed
check_gh_cli() {
    print_status "Checking GitHub CLI installation..."
    
    if ! command -v gh &> /dev/null; then
        print_warning "GitHub CLI not found. You'll need to create the repository manually."
        print_status "Install GitHub CLI: https://cli.github.com/"
        return 1
    fi
    
    print_success "GitHub CLI found"
}

# Get repository details
get_repo_details() {
    echo ""
    echo "📝 Repository Details"
    echo "===================="
    
    # Get current directory name as default repo name
    DEFAULT_REPO_NAME=$(basename "$PWD")
    
    read -p "Repository name [$DEFAULT_REPO_NAME]: " REPO_NAME
    REPO_NAME=${REPO_NAME:-$DEFAULT_REPO_NAME}
    
    read -p "Repository description: " REPO_DESCRIPTION
    REPO_DESCRIPTION=${REPO_DESCRIPTION:-"AWS-based inventory synchronization system for Valley Ridge"}
    
    read -p "GitHub username/organization: " GITHUB_USER
    
    echo ""
    echo "Repository will be created as: $GITHUB_USER/$REPO_NAME"
    echo "Description: $REPO_DESCRIPTION"
    echo ""
    
    read -p "Continue? (y/N): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        print_warning "Setup cancelled"
        exit 0
    fi
}

# Create GitHub repository
create_github_repo() {
    print_status "Creating GitHub repository..."
    
    if command -v gh &> /dev/null; then
        # Use GitHub CLI to create repository
        gh repo create "$GITHUB_USER/$REPO_NAME" \
            --description "$REPO_DESCRIPTION" \
            --public \
            --source=. \
            --remote=origin \
            --push
        
        print_success "GitHub repository created and code pushed"
    else
        print_warning "GitHub CLI not available. Please create the repository manually:"
        echo ""
        echo "1. Go to https://github.com/new"
        echo "2. Repository name: $REPO_NAME"
        echo "3. Description: $REPO_DESCRIPTION"
        echo "4. Make it Public"
        echo "5. Don't initialize with README (we already have one)"
        echo "6. Click 'Create repository'"
        echo ""
        echo "Then run these commands:"
        echo "git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git"
        echo "git branch -M main"
        echo "git push -u origin main"
        echo ""
        
        read -p "Press Enter after creating the repository..."
        
        # Add remote and push
        git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
        git branch -M main
        git push -u origin main
        
        print_success "Code pushed to GitHub repository"
    fi
}

# Set up branch protection (if using GitHub CLI)
setup_branch_protection() {
    if command -v gh &> /dev/null; then
        print_status "Setting up branch protection..."
        
        # Enable branch protection for main branch
        gh api repos/$GITHUB_USER/$REPO_NAME/branches/main/protection \
            --method PUT \
            --field required_status_checks='{"strict":true,"contexts":[]}' \
            --field enforce_admins=true \
            --field required_pull_request_reviews='{"required_approving_review_count":1}' \
            --field restrictions=null
        
        print_success "Branch protection enabled for main branch"
    else
        print_warning "GitHub CLI not available. Please set up branch protection manually:"
        echo "1. Go to repository Settings > Branches"
        echo "2. Add rule for 'main' branch"
        echo "3. Enable 'Require pull request reviews before merging'"
        echo "4. Enable 'Require status checks to pass before merging'"
        echo "5. Enable 'Include administrators'"
    fi
}

# Create initial issues and milestones
create_project_structure() {
    if command -v gh &> /dev/null; then
        print_status "Creating project structure..."
        
        # Create labels
        gh api repos/$GITHUB_USER/$REPO_NAME/labels \
            --method POST \
            --field name="enhancement" \
            --field description="New feature or request" \
            --field color="a2eeef"
        
        gh api repos/$GITHUB_USER/$REPO_NAME/labels \
            --method POST \
            --field name="bug" \
            --field description="Something isn't working" \
            --field color="d73a4a"
        
        gh api repos/$GITHUB_USER/$REPO_NAME/labels \
            --method POST \
            --field name="documentation" \
            --field description="Improvements or additions to documentation" \
            --field color="0075ca"
        
        gh api repos/$GITHUB_USER/$REPO_NAME/labels \
            --method POST \
            --field name="good first issue" \
            --field description="Good for newcomers" \
            --field color="7057ff"
        
        print_success "Project labels created"
        
        # Create initial milestone
        gh api repos/$GITHUB_USER/$REPO_NAME/milestones \
            --method POST \
            --field title="v1.0.0 - Production Release" \
            --field description="Initial production release of the inventory sync system"
        
        print_success "Initial milestone created"
    else
        print_warning "GitHub CLI not available. Please create project structure manually:"
        echo "1. Go to repository Issues > Labels"
        echo "2. Create labels: enhancement, bug, documentation, good first issue"
        echo "3. Go to repository Issues > Milestones"
        echo "4. Create milestone: v1.0.0 - Production Release"
    fi
}

# Display next steps
show_next_steps() {
    echo ""
    echo "🎉 GitHub Repository Setup Complete!"
    echo "==================================="
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Review the repository at: https://github.com/$GITHUB_USER/$REPO_NAME"
    echo "2. Set up branch protection rules"
    echo "3. Create project labels and milestones"
    echo "4. Add collaborators if needed"
    echo "5. Set up GitHub Actions for CI/CD (optional)"
    echo ""
    echo "🔧 Development Workflow:"
    echo "======================="
    echo "1. Create feature branches: git checkout -b feature/new-feature"
    echo "2. Make changes and commit: git commit -m 'feat: add new feature'"
    echo "3. Push and create PR: git push origin feature/new-feature"
    echo "4. Review and merge through GitHub"
    echo ""
    echo "📚 Documentation:"
    echo "================"
    echo "- README.md: Project overview and setup"
    echo "- CONTRIBUTING.md: Contribution guidelines"
    echo "- docs/: Detailed documentation"
    echo "- scripts/: Deployment and testing scripts"
    echo ""
    echo "🚀 Ready to deploy:"
    echo "=================="
    echo "./scripts/deploy-incremental.sh"
    echo "./scripts/test-incremental.sh"
    echo ""
}

# Main setup process
main() {
    echo "Starting GitHub repository setup..."
    echo ""
    
    check_git
    check_gh_cli
    get_repo_details
    create_github_repo
    setup_branch_protection
    create_project_structure
    show_next_steps
    
    print_success "GitHub repository setup completed successfully!"
}

# Run main function
main "$@" 