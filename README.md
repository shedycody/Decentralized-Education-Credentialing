# 🎓 EduCredentialing

A decentralized education credentialing system built on the Stacks blockchain. Issue and verify academic credentials as NFTs, eliminating fraud and reducing administrative overhead.

## 🌟 Features

- 🏫 **Institution Registration**: Educational institutions can register and get verified
- 📜 **NFT Credentials**: Issue academic credentials as unique NFTs
- ✅ **Instant Verification**: Employers can verify credentials without contacting institutions
- 🔒 **Fraud Prevention**: Blockchain-based immutable credential records
- ⏰ **Expiration Support**: Set expiration dates for time-sensitive credentials
- 🗃️ **IPFS Integration**: Store credential metadata on IPFS

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd Decentralized-Education-Credentialing
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📋 Usage

### For Educational Institutions

#### 1. Register Institution 🏢
```clarity
(contract-call? .EduCredentialing register-institution "University of Example" "A leading institution in technology education")
```

#### 2. Issue Credential 📄
```clarity
(contract-call? .EduCredentialing issue-credential 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7    ;; recipient
    "Bachelor of Science"                              ;; credential-type
    "Computer Science"                                ;; field-of-study
    "Undergraduate"                                   ;; degree-level
    (some u2100000)                                   ;; optional expiry block
    "QmX1Y2Z3..."                                     ;; IPFS hash
)
```

### For Employers/Verifiers

#### 1. Verify Credential ✅
```clarity
(contract-call? .EduCredentialing verify-credential u1)
```

#### 2. Check Credential Details 🔍
```clarity
(contract-call? .EduCredentialing get-credential u1)
```

#### 3. Validate Credential Status 📊
```clarity
(contract-call? .EduCredentialing is-credential-valid u1)
```

### For Contract Owner

#### 1. Verify Institution 🛡️
```clarity
(contract-call? .EduCredentialing verify-institution 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🏗️ Contract Structure

### Data Maps

- **institutions**: Store institution information and verification status
- **credentials**: Store all credential data including metadata
- **recipient-credentials**: Track credentials by recipient
- **credential-recipients-count**: Count credentials per recipient

### Key Functions

| Function | Description | Access |
|----------|-------------|--------|
| `register-institution` | Register as an educational institution | Public |
| `verify-institution` | Verify an institution (owner only) | Owner |
| `issue-credential` | Issue a new credential NFT | Verified Institutions |
| `verify-credential` | Check if credential is valid | Read-only |
| `revoke-credential` | Revoke an issued credential | Institution |
| `get-credential` | Get credential details | Read-only |

## 🔐 Security Features

- ✅ Only verified institutions can issue credentials
- ✅ Institutions can only revoke their own credentials
- ✅ NFT ownership proves credential ownership
- ✅ Expiration date validation
- ✅ Owner-only institution verification

## 📱 Frontend Integration

Use the following read-only functions for frontend applications:

```javascript
// Get credential details
await stacksClient.callReadOnlyFunction({
  contractAddress: 'YOUR_CONTRACT_ADDRESS',
  contractName: 'EduCredentialing',
  functionName: 'get-credential',
  functionArgs: [uintCV(credentialId)]
});

// Verify credential validity
await stacksClient.callReadOnlyFunction({
  contractAddress: 'YOUR_CONTRACT_ADDRESS',
  contractName: 'EduCredentialing', 
  functionName: 'is-credential-valid',
  functionArgs: [uintCV(credentialId)]
});
```

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

Test specific scenarios:
- Institution registration and verification
- Credential issuance and validation
- Expiration handling
- Authorization checks

## 📊 Statistics

Get system statistics:

```clarity
;; Total institutions
(contract-call? .EduCredentialing get-total-institutions)

;; Total credentials issued
(contract-call? .EduCredentialing get-total-credentials)

;; Recipient credential count
(contract-call? .EduCredentialing get-recipient-credential-count 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run `clarinet check` and `clarinet test`
6. Submit a pull request

## 📜 License

MIT License - see LICENSE file for details.

## 🙋‍♀️ Support

For questions or issues:
- Open a GitHub issue
- Contact the development team
- Check the Stacks documentation

---

*Built with ❤️ on the Stacks blockchain*
