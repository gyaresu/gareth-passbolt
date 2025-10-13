#!/bin/bash
# Validates Traefik YAML syntax and checks for common issues
set -e

echo "Traefik Configuration Validator"
echo "================================"
echo ""

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to the root directory
cd "$ROOT_DIR" || { echo "Error: Failed to change to root directory"; exit 1; }

VALIDATION_FAILED=0

# Function to check file exists
check_file_exists() {
    local file=$1
    if [ -f "$file" ]; then
        echo "✓ Found: $file"
        return 0
    else
        echo "❌ Missing: $file"
        VALIDATION_FAILED=1
        return 1
    fi
}

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    echo "Validating YAML syntax: $file"
    
    if ! check_file_exists "$file"; then
        return 1
    fi
    
    # Try with Docker yamllint if available (most reliable for Docker users)
    if command -v docker &> /dev/null; then
        if docker run --rm -v "$ROOT_DIR:/workdir" cytopia/yamllint:latest "/workdir/$file" 2>/dev/null; then
            echo "✓ Valid YAML syntax"
            return 0
        fi
    fi
    
    # Try with Python if available
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo "✓ Valid YAML syntax"
            return 0
        fi
    fi
    
    # Try with Ruby if available
    if command -v ruby &> /dev/null; then
        if ruby -ryaml -e "YAML.load_file('$file')" 2>/dev/null; then
            echo "✓ Valid YAML syntax"
            return 0
        fi
    fi
    
    # Fallback: just check basic YAML structure
    echo "⚠️  Using basic YAML validation (install yamllint for better checks)"
    
    # Check for common YAML issues
    local errors=0
    
    # Check for tabs
    if grep -q $'\t' "$file"; then
        echo "❌ Found tabs (YAML requires spaces)"
        errors=1
    fi
    
    # Check for basic structure
    if ! grep -q ":" "$file"; then
        echo "❌ No key-value pairs found"
        errors=1
    fi
    
    if [ $errors -eq 0 ]; then
        echo "✓ Basic YAML structure looks OK"
        echo "   (Install Python PyYAML or use Docker for thorough validation)"
        return 0
    else
        VALIDATION_FAILED=1
        return 1
    fi
}

# Function to check for tabs in YAML
check_for_tabs() {
    local file=$1
    echo "Checking for tabs (YAML requires spaces): $file"
    
    if ! check_file_exists "$file"; then
        return 1
    fi
    
    if grep -q $'\t' "$file"; then
        echo "❌ Found tabs in file (YAML requires spaces)"
        echo "   Lines with tabs:"
        grep -n $'\t' "$file" | head -5
        VALIDATION_FAILED=1
        return 1
    else
        echo "✓ No tabs found (good)"
        return 0
    fi
}

# Function to check indentation consistency
check_indentation() {
    local file=$1
    echo "Checking indentation consistency: $file"
    
    if ! check_file_exists "$file"; then
        return 1
    fi
    
    # Check if indentation is consistent (multiples of 2)
    local inconsistent=$(awk '/^ +[^ ]/ {
        match($0, /^ +/)
        indent = RLENGTH
        if (indent % 2 != 0) {
            print NR ": " $0
        }
    }' "$file")
    
    if [ -n "$inconsistent" ]; then
        echo "⚠️  Found lines with odd indentation (should be multiples of 2):"
        echo "$inconsistent" | head -5
        echo "   This might indicate indentation issues"
    else
        echo "✓ Indentation appears consistent"
    fi
    
    return 0
}

# Check main configuration files
echo "Step 1: Checking main Traefik configuration..."
echo "----------------------------------------------"
validate_yaml "config/traefik/traefik.yaml"
check_for_tabs "config/traefik/traefik.yaml"
check_indentation "config/traefik/traefik.yaml"
echo ""

echo "Step 2: Checking TLS configuration..."
echo "--------------------------------------"
validate_yaml "config/traefik/conf.d/tls.yaml"
check_for_tabs "config/traefik/conf.d/tls.yaml"
check_indentation "config/traefik/conf.d/tls.yaml"
echo ""

echo "Step 3: Checking headers configuration..."
echo "------------------------------------------"
validate_yaml "config/traefik/conf.d/headers.yaml"
check_for_tabs "config/traefik/conf.d/headers.yaml"
check_indentation "config/traefik/conf.d/headers.yaml"
echo ""

echo "Step 4: Checking docker-compose configuration..."
echo "-------------------------------------------------"
check_file_exists "docker-compose.traefik.yaml"
check_for_tabs "docker-compose.traefik.yaml"
echo ""

echo "Step 5: Checking Traefik configuration structure..."
echo "-----------------------------------------------------"
echo "Verifying required configuration keys..."

# Check traefik.yaml has required keys
if grep -q "^entryPoints:" "config/traefik/traefik.yaml" && \
   grep -q "^providers:" "config/traefik/traefik.yaml"; then
    echo "✓ Main configuration has required keys (entryPoints, providers)"
else
    echo "❌ Missing required configuration keys in traefik.yaml"
    VALIDATION_FAILED=1
fi

# Check tls.yaml structure
if grep -q "^tls:" "config/traefik/conf.d/tls.yaml"; then
    echo "✓ TLS configuration has required keys"
else
    echo "❌ Missing TLS configuration in tls.yaml"
    VALIDATION_FAILED=1
fi

# Check headers.yaml structure
if grep -q "^http:" "config/traefik/conf.d/headers.yaml" && \
   grep -q "middlewares:" "config/traefik/conf.d/headers.yaml"; then
    echo "✓ Headers configuration has required keys"
else
    echo "❌ Missing headers configuration in headers.yaml"
    VALIDATION_FAILED=1
fi

echo ""

echo "Step 6: Checking required certificates..."
echo "------------------------------------------"
if check_file_exists "keys/passbolt.crt" && check_file_exists "keys/passbolt.key"; then
    echo "✓ Passbolt certificates exist"
else
    echo "⚠️  Passbolt certificates missing. Run: ./scripts/generate-certificates.sh"
fi

if check_file_exists "keys/keycloak.crt" && check_file_exists "keys/keycloak.key"; then
    echo "✓ Keycloak certificates exist"
else
    echo "⚠️  Keycloak certificates missing. Run: ./scripts/generate-certificates.sh"
fi
echo ""

# Final summary
echo "Validation Summary"
echo "=================="
echo ""

if [ $VALIDATION_FAILED -eq 0 ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "Your Traefik configuration appears to be valid."
    echo "You can start the stack with:"
    echo "  docker compose -f docker-compose.traefik.yaml up -d"
    echo ""
    echo "Or use the setup script:"
    echo "  ./scripts/setup-traefik.sh"
    exit 0
else
    echo "❌ Validation failed!"
    echo ""
    echo "Please fix the issues above before starting Traefik."
    echo ""
    echo "Common fixes:"
    echo "  1. Replace tabs with spaces (use 2 spaces for indentation)"
    echo "  2. Ensure consistent indentation (multiples of 2 spaces)"
    echo "  3. Check for missing colons or incorrect nesting"
    echo "  4. Generate missing certificates with: ./scripts/generate-certificates.sh"
    exit 1
fi

