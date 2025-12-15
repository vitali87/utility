#!/usr/bin/env bash
# Test suite for u7 CLI
# Run with: nix develop --command bash test.sh

# Don't exit on error - we want to run all tests
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Source the utility
source ./utility.sh

# Test helper
assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Got: $actual"
        ((FAILED++))
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Got: $haystack"
        ((FAILED++))
    fi
}

# Setup test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

echo "Running u7 tests..."
echo "==================="

# Test 1: JSON limit default
echo '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]' > test.json
result=$(u7 show json test.json 2>&1)
line_count=$(echo "$result" | wc -l | tr -d ' ')
assert_equals "JSON default limit shows 10 items" "12" "$line_count"  # 10 items + [ + ]

# Test 2: JSON custom limit
result=$(u7 show json test.json limit 3 2>&1)
if [[ $? -eq 0 ]]; then
    line_count=$(echo "$result" | wc -l | tr -d ' ')
    assert_equals "JSON custom limit shows 3 items" "5" "$line_count"  # 3 items + [ + ]
else
    echo -e "${RED}✗${NC} JSON custom limit shows 3 items (command failed)"
    echo "  Output: $result"
    ((FAILED++))
fi

# Test 3: Text replacement with literal dot
echo "foo.bar is here and fooXbar too" > test_replace.txt
u7 set text "foo.bar" to "baz" in test_replace.txt >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    result=$(cat test_replace.txt)
    assert_equals "Text replacement treats dot literally" "baz is here and fooXbar too" "$result"
else
    echo -e "${RED}✗${NC} Text replacement treats dot literally (command failed)"
    ((FAILED++))
fi

# Test 4: Text replacement with special chars
echo "price is \$100" > test_special.txt
u7 set text "\$100" to "\$200" in test_special.txt >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    result=$(cat test_special.txt)
    assert_equals "Text replacement handles dollar signs" "price is \$200" "$result"
else
    echo -e "${RED}✗${NC} Text replacement handles dollar signs (command failed)"
    ((FAILED++))
fi

# Test 5: Password generation
result=$(u7 make password 16)
length=${#result}
assert_equals "Password generation creates 16 chars" "16" "$length"

# Test 6: Directory creation
u7 make dir testdir
if [[ -d "testdir" ]]; then
    echo -e "${GREEN}✓${NC} Directory creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Directory creation works"
    ((FAILED++))
fi

# Test 7: File creation
u7 make file testfile.txt
if [[ -f "testfile.txt" ]]; then
    echo -e "${GREEN}✓${NC} File creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} File creation works"
    ((FAILED++))
fi

# Test 8: Archive extraction to directory
echo "test content" > testfile.txt
gzip testfile.txt  # Creates testfile.txt.gz
mkdir extract_dir
u7 convert archive to files testfile.txt.gz extract_dir >/dev/null 2>&1
if [[ -f "extract_dir/testfile.txt" ]]; then
    echo -e "${GREEN}✓${NC} Archive extraction to directory works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Archive extraction to directory works"
    echo "  Expected: extract_dir/testfile.txt"
    ls -la extract_dir/
    ((FAILED++))
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo "==================="
echo "Tests passed: $PASSED"
echo "Tests failed: $FAILED"
echo "==================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
