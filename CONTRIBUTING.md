# Contributing to Valley Ridge Inventory Sync

Thank you for your interest in contributing to the Valley Ridge Inventory Sync system! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Check existing issues** to see if your problem has already been reported
2. **Search the documentation** in the `docs/` directory
3. **Provide detailed information** including:
   - Description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (AWS region, Node.js version, etc.)
   - Error messages and logs

### Suggesting Features

When suggesting new features:

1. **Describe the use case** and why it's needed
2. **Provide examples** of how it would work
3. **Consider the impact** on existing functionality
4. **Check the roadmap** to see if it's already planned

## 🛠️ Development Setup

### Prerequisites

- **AWS CLI** configured with appropriate permissions
- **AWS SAM CLI** installed
- **Node.js** 18.x or later
- **Git** for version control

### Local Development

1. **Fork and clone** the repository:
   ```bash
   git clone https://github.com/your-username/valleyridge-inventory-sync.git
   cd valleyridge-inventory-sync
   ```

2. **Install dependencies**:
   ```bash
   cd functions/process-inventory
   npm install
   cd ../..
   ```

3. **Set up credentials** (create `credentials/` directory with your files)

4. **Test your changes**:
   ```bash
   ./scripts/test-incremental.sh
   ```

## 📝 Code Style Guidelines

### JavaScript/Node.js

- Use **ES6+** features where appropriate
- Follow **async/await** patterns for asynchronous code
- Use **const** and **let** instead of **var**
- Add **JSDoc comments** for functions and classes
- Keep functions **small and focused**

### AWS SAM Templates

- Use **consistent indentation** (2 spaces)
- Add **descriptions** for all resources
- Use **parameters** for configurable values
- Include **tags** for resource management

### Documentation

- Write **clear and concise** documentation
- Include **examples** where helpful
- Update **README.md** for significant changes
- Add **inline comments** for complex logic

## 🔄 Git Workflow

### Branch Strategy

- `main`: Production-ready code
- `develop`: Development branch
- `feature/*`: Feature branches
- `hotfix/*`: Emergency fixes
- `docs/*`: Documentation updates

### Commit Messages

Use conventional commit format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Maintenance tasks

**Examples:**
```bash
git commit -m "feat: add email notification system"
git commit -m "fix: resolve case-insensitive header matching"
git commit -m "docs: update deployment instructions"
git commit -m "test: add incremental processing tests"
```

### Pull Request Process

1. **Create a feature branch** from `develop`
2. **Make your changes** following the style guidelines
3. **Test your changes** thoroughly
4. **Update documentation** if needed
5. **Commit with conventional messages**
6. **Push to your fork**
7. **Create a Pull Request** with:
   - Clear description of changes
   - Link to related issues
   - Screenshots if UI changes
   - Test results

## 🧪 Testing Guidelines

### Automated Testing

- **Run existing tests** before making changes
- **Add tests** for new functionality
- **Update tests** when fixing bugs
- **Test edge cases** and error conditions

### Manual Testing

- **Test with sample data** before submitting
- **Verify AWS integration** works correctly
- **Check CloudWatch logs** for errors
- **Validate S3 file processing**

### Test Data

- Use **sample Excel files** for testing
- **Don't commit** real inventory data
- **Anonymize** any test data
- **Document** test scenarios

## 🔒 Security Considerations

### Credentials and Secrets

- **Never commit** credentials or secrets
- Use **environment variables** for configuration
- **Rotate credentials** regularly
- **Use IAM roles** with least privilege

### Code Security

- **Validate input data** thoroughly
- **Sanitize file uploads**
- **Use parameterized queries** (if applicable)
- **Follow AWS security best practices**

## 📚 Documentation Standards

### Code Documentation

- **Document complex functions** with JSDoc
- **Explain business logic** in comments
- **Include examples** for public APIs
- **Update README** for new features

### User Documentation

- **Write clear instructions** for setup and usage
- **Include troubleshooting** sections
- **Provide examples** for common tasks
- **Keep documentation** up to date

## 🚀 Deployment Guidelines

### Testing Deployment

- **Test in staging** before production
- **Use different stack names** for testing
- **Validate CloudFormation templates**
- **Check IAM permissions**

### Production Deployment

- **Review changes** thoroughly
- **Backup existing data** if needed
- **Deploy during low-traffic periods**
- **Monitor closely** after deployment

## 🐛 Bug Fixes

### Before Fixing

1. **Reproduce the issue** consistently
2. **Identify the root cause**
3. **Check for similar issues**
4. **Plan the fix** carefully

### During Fixing

1. **Make minimal changes** to fix the issue
2. **Add tests** to prevent regression
3. **Update documentation** if needed
4. **Test thoroughly** before submitting

### After Fixing

1. **Document the fix** in commit message
2. **Link to related issues**
3. **Update changelog** if applicable
4. **Monitor for regressions**

## 🎯 Feature Development

### Planning

1. **Define requirements** clearly
2. **Consider user impact**
3. **Plan testing strategy**
4. **Estimate effort** realistically

### Implementation

1. **Follow existing patterns**
2. **Add comprehensive tests**
3. **Update documentation**
4. **Consider backward compatibility**

### Review

1. **Self-review** your changes
2. **Test thoroughly**
3. **Update related documentation**
4. **Prepare for code review**

## 📞 Getting Help

### Questions and Support

- **Check documentation** first
- **Search existing issues**
- **Ask in discussions** for general questions
- **Create an issue** for bugs or feature requests

### Code Review

- **Be open to feedback**
- **Respond to review comments**
- **Make requested changes**
- **Ask questions** if unclear

## 🙏 Recognition

Contributors will be recognized in:

- **README.md** contributors section
- **Release notes** for significant contributions
- **GitHub contributors** page

Thank you for contributing to the Valley Ridge Inventory Sync system! 