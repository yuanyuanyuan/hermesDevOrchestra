#!/usr/bin/env bash
# Test: Channel Security Escape
# Tests security escape rules for forcing Standard channel

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Add lib directory to Python path
export PYTHONPATH="${REPO_ROOT}/scripts/lib:${PYTHONPATH:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}✗ FAIL${NC}: $1"
}

echo "=========================================="
echo "Test: Channel Security Escape"
echo "=========================================="
echo ""

# Test 1: Import security escape module
echo "Test 1: Import security escape module"
if python3 -c "from security_escape import detect_security_escape, force_standard_for_security, validate_security_escape, SecurityEscapeError; print('OK')"; then
    pass "Module imports successfully"
else
    fail "Module import failed"
fi

# Test 2: Detect password pattern in file path
echo ""
echo "Test 2: Detect password pattern in file path"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['config/password.txt'])
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Password pattern detected in file path"
else
    fail "Password pattern not detected"
fi

# Test 3: Detect secret pattern in file path
echo ""
echo "Test 3: Detect secret pattern in file path"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['config/secrets.json'])
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Secret pattern detected in file path"
else
    fail "Secret pattern not detected"
fi

# Test 4: Detect token pattern in file path
echo ""
echo "Test 4: Detect token pattern in file path"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['config/token.txt'])
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Token pattern detected in file path"
else
    fail "Token pattern not detected"
fi

# Test 5: Detect protected target pattern
echo ""
echo "Test 5: Detect protected target pattern"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['config/release/commands.json'])
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Protected target pattern detected"
else
    fail "Protected target pattern not detected"
fi

# Test 6: Detect pattern in file contents
echo ""
echo "Test 6: Detect pattern in file contents"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['app.py'], {'app.py': 'password = \"secret123\"'})
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Pattern detected in file contents"
else
    fail "Pattern not detected in file contents"
fi

# Test 7: No security patterns detected
echo ""
echo "Test 7: No security patterns detected"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['README.md', 'src/main.py'])
print(len(matched) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "No security patterns detected (correct)"
else
    fail "Security patterns incorrectly detected"
fi

# Test 8: Force standard for security
echo ""
echo "Test 8: Force standard for security"
RESULT=$(python3 -c "
from security_escape import force_standard_for_security
run = {'run_id': 'run-1'}
updated = force_standard_for_security(run, ['config/password.txt'])
print(updated['channel_decision']['forced_standard'] == True and updated['channel_decision']['channel'] == 'standard')
")
if [ "$RESULT" = "True" ]; then
    pass "Standard forced for security-sensitive diff"
else
    fail "Standard not forced for security-sensitive diff"
fi

# Test 9: forced_standard_reasons populated
echo ""
echo "Test 9: forced_standard_reasons populated"
RESULT=$(python3 -c "
from security_escape import force_standard_for_security
run = {'run_id': 'run-2'}
updated = force_standard_for_security(run, ['config/password.txt'])
reasons = updated['channel_decision']['forced_standard_reasons']
print(len(reasons) > 0 and 'security_pattern:' in reasons[0])
")
if [ "$RESULT" = "True" ]; then
    pass "forced_standard_reasons populated correctly"
else
    fail "forced_standard_reasons not populated"
fi

# Test 10: No forced standard for safe files
echo ""
echo "Test 10: No forced standard for safe files"
RESULT=$(python3 -c "
from security_escape import force_standard_for_security
run = {'run_id': 'run-3'}
updated = force_standard_for_security(run, ['README.md', 'src/main.py'])
print('channel_decision' not in updated or not updated.get('channel_decision', {}).get('forced_standard'))
")
if [ "$RESULT" = "True" ]; then
    pass "No forced standard for safe files"
else
    fail "Forced standard incorrectly applied to safe files"
fi

# Test 11: Multiple files with security patterns detected
echo ""
echo "Test 11: Multiple files with security patterns detected"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['config/password.txt', 'config/secrets.json', 'config/token.txt'])
print(len(matched) >= 1)  # All match same pattern, deduplicated
")
if [ "$RESULT" = "True" ]; then
    pass "Multiple files with security patterns detected"
else
    fail "Multiple files with security patterns not detected"
fi

# Test 12: Validate security escape - valid
echo ""
echo "Test 12: Validate security escape - valid"
RESULT=$(python3 -c "
from security_escape import validate_security_escape
run = {'run_id': 'run-4', 'channel_decision': {'forced_standard': True, 'forced_standard_reasons': ['security_pattern:password'], 'channel': 'standard'}}
errors = validate_security_escape(run)
print(len(errors) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Valid security escape passes validation"
else
    fail "Valid security escape fails validation"
fi

# Test 13: Validate security escape - missing reasons
echo ""
echo "Test 13: Validate security escape - missing reasons"
RESULT=$(python3 -c "
from security_escape import validate_security_escape
run = {'run_id': 'run-5', 'channel_decision': {'forced_standard': True}}
errors = validate_security_escape(run)
print(len(errors) > 0 and 'forced_standard_reasons' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Missing forced_standard_reasons detected"
else
    fail "Missing forced_standard_reasons not detected"
fi

# Test 14: Database pattern detected
echo ""
echo "Test 14: Database pattern detected"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['migrations/001.sql'], {'migrations/001.sql': 'DROP TABLE users;'})
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Database pattern detected"
else
    fail "Database pattern not detected"
fi

# Test 15: Detect PII pattern in file contents
echo ""
echo "Test 15: Detect PII pattern in file contents"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['profile.py'], {'profile.py': 'ssn = \"123-45-6789\"'})
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "PII pattern detected in file contents"
else
    fail "PII pattern not detected in file contents"
fi

# Test 16: Detect encryption pattern in file contents
echo ""
echo "Test 16: Detect encryption pattern in file contents"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['auth.py'], {'auth.py': 'password_hash = bcrypt.hashpw(password, salt)'})
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Encryption pattern detected in file contents"
else
    fail "Encryption pattern not detected in file contents"
fi

# Test 17: Detect network security pattern in file contents
echo ""
echo "Test 17: Detect network security pattern in file contents"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['server.py'], {'server.py': 'ssl = True'})
print(len(matched) > 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Network security pattern detected in file contents"
else
    fail "Network security pattern not detected in file contents"
fi

# Test 18: No false positive for ordinary hash text
echo ""
echo "Test 18: No false positive for ordinary hash text"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['collections.py'], {'collections.py': 'hash map implementation'})
print(len(matched) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Ordinary hash text does not force standard"
else
    fail "Ordinary hash text incorrectly forces standard"
fi

# Test 19: No false positive for network substrings
echo ""
echo "Test 19: No false positive for network substrings"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['docs/network.md'], {'docs/network.md': 'This task updates proxyman fixtures and certificateless docs.'})
print(len(matched) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Network substrings do not force standard"
else
    fail "Network substrings incorrectly force standard"
fi

# Test 20: Validate security escape - forced standard requires standard channel
echo ""
echo "Test 20: Validate security escape - forced standard requires standard channel"
RESULT=$(python3 -c "
from security_escape import validate_security_escape
run = {'run_id': 'run-6', 'channel_decision': {'forced_standard': True, 'forced_standard_reasons': ['security_pattern:password'], 'channel': 'quick'}}
errors = validate_security_escape(run)
print(len(errors) > 0 and 'channel is not standard' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Non-standard channel detected for forced standard"
else
    fail "Non-standard channel not detected for forced standard"
fi

# Test 21: Validate security escape - invalid reason prefix
echo ""
echo "Test 21: Validate security escape - invalid reason prefix"
RESULT=$(python3 -c "
from security_escape import validate_security_escape
run = {'run_id': 'run-7', 'channel_decision': {'forced_standard': True, 'forced_standard_reasons': ['password'], 'channel': 'standard'}}
errors = validate_security_escape(run)
print(len(errors) > 0 and 'security_pattern:' in errors[0])
")
if [ "$RESULT" = "True" ]; then
    pass "Invalid reason prefix detected"
else
    fail "Invalid reason prefix not detected"
fi

# Test 22: No false positive for auth substrings
echo ""
echo "Test 22: No false positive for auth substrings"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
matched = detect_security_escape(['test_tokenizer.py', 'docs/authentication_password_flow.md'])
print(len(matched) == 0)
")
if [ "$RESULT" = "True" ]; then
    pass "Auth substrings do not force standard"
else
    fail "Auth substrings incorrectly force standard"
fi

# Test 23: Empty input returns no matches
echo ""
echo "Test 23: Empty input returns no matches"
RESULT=$(python3 -c "
from security_escape import detect_security_escape
print(detect_security_escape([]) == [] and detect_security_escape([], {}) == [])
")
if [ "$RESULT" = "True" ]; then
    pass "Empty input returns no matches"
else
    fail "Empty input did not return no matches"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}${PASS_COUNT}${NC}"
echo -e "Failed: ${RED}${FAIL_COUNT}${NC}"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
