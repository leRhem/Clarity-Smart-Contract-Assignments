# Clarity Smart Contract Assignments - Starter Code Templates

## Submission Guidelines

### Repository Setup

**Students must fork the starter repository and complete assignments in their fork.**

#### Repository Structure

Your forked repository should maintain this structure:

```
clarity-smart-contract-assignments/
│
├── README.md (update with your name and progress)
│
├── Assignment_1_Hello_World_Registry/
│   ├── contract_code.clar
│   ├── Documentation.md
│   └── README.md
│
├── Assignment_2_Voting_System/
│   ├── contract_code.clar
│   ├── Documentation.md
│   └── README.md
│
├── Assignment_3_Timelock_Wallet/
│   ├── contract_code.clar
│   ├── Documentation.md
│   └── README.md
│
├── Assignment_4_Escrow_Contract/
│   ├── contract_code.clar
│   ├── Documentation.md
│   └── README.md
│
└── Assignment_5_NFT_Marketplace/
    ├── contract_code.clar
    ├── Documentation.md
    └── README.md
```

### Submission Process

1. **Fork** the starter repository provided by your instructor
2. **Clone** your forked repository to your local machine:
   ```bash
   git clone https://github.com/YOUR_USERNAME/clarity-smart-contract-assignments.git
   cd clarity-smart-contract-assignments
   ```

3. **Update** the main README.md (This) with your information:
   ```markdown
   # Clarity Smart Contract Assignments
   
   **Student Name:** Your Name
   **Cohort:** [Your Cohort]
   **Submission Date:** [Date]
   
   ## Progress Tracker
   - [x] Assignment 1: Hello World Registry
   - [ ] Assignment 2: Voting System
   - [ ] Assignment 3: Timelock Wallet
   - [ ] Assignment 4: Escrow Contract
   - [ ] Assignment 5: NFT Marketplace
   ```

4. **Complete** each assignment in its respective folder:
   - Write your contract code in `contract_code.clar`
   - Document your work in `Documentation.md`

5. **Commit** your work regularly with meaningful messages:
   ```bash
   git add Assignment_1_Hello_World_Registry/
   git commit -m "Complete Assignment 1: Hello World Registry"
   git push origin main
   ```

6. **Submit** by providing your repository URL when all assignments are complete

### File Requirements

**1. contract_code.clar**
- Must be a valid Clarity contract file
- Can be developed in the Clarity playground, then copied to repository
- Must include all required functions
- Should be properly commented

**2. Documentation.md**
- Must be in Markdown format
- Should include the following sections:

```markdown
# Assignment [Number]: [Contract Name]

## Student Information
- Name: [Your Name]
- Date: [Submission Date]

## Contract Overview
[Brief description of what your contract does]

## Assumptions Made
- [List any assumptions about how the contract should work]
- [Example: "Assumed that once a message is deleted, it cannot be recovered"]
- [Example: "Assumed prices are always in micro-STX (1 STX = 1,000,000 micro-STX)"]

## Design Decisions and Tradeoffs

### Decision 1: [Title]
- **What I chose:** [Describe your choice]
- **Why:** [Explain reasoning]
- **Tradeoff:** [What you gained vs what you gave up]

### Decision 2: [Title]
- **What I chose:** [Describe your choice]
- **Why:** [Explain reasoning]
- **Tradeoff:** [What you gained vs what you gave up]

[Add more as needed]

## How to Use This Contract

### Function: function-name
- **Purpose:** [What it does]
- **Parameters:** 
  - `param1`: [description]
  - `param2`: [description]
- **Returns:** [What it returns]
- **Example:**
  ```clarity
  (contract-call? .contract-name function-name param1 param2)
[Document all public functions]

## Known Limitations
- [List any known issues or limitations]
- [Example: "Does not handle the case where..."]
- [Example: "Maximum message length is limited to 500 characters"]

## Future Improvements
- [Optional: List potential enhancements]
- [Example: "Could add batch operations for efficiency"]

## Testing Notes
- [Describe how you tested the contract]
- [List key test cases you verified]
```

### Git Best Practices

- **Commit often**: Don't wait until all assignments are done
- **Write clear commit messages**: Describe what you changed and why
- **One assignment per commit**: Makes it easier to track progress
- **Don't commit sensitive data**: No private keys or personal information
- **Keep your fork updated**: Pull any updates from the original repository if needed

### Important Notes

- ✅ Fork the starter repository before beginning work
- ✅ Maintain the exact folder structure provided
- ✅ Commit your work regularly with clear messages
- ✅ You can develop in the playground, but code must be in the repository
- ✅ Documentation must explain your design choices, not just describe functions
- ✅ Update the main README.md with your progress
- ✅ Submit your repository URL when ready for grading
- ❌ Do not modify the folder names
- ❌ Do not delete or rename provided files
- ❌ Do not commit compiled files or deployment artifacts
- ❌ Do not wait until the last minute to commit everything

### Final Submission

When all assignments are complete:

1. **Verify** all files are committed and pushed to GitHub
2. **Double-check** that your repository is public (or accessible to instructor)
3. **Test** that your repository URL works in an incognito/private browser window
4. **Submit** your repository URL in the format:
   ```
   https://github.com/YOUR_USERNAME/clarity-smart-contract-assignments
   ```
5. Submission link will be provider in the group chat.
---

## Example Completed Documentation (check Assignment 1)

## Assignment Overview

### Assignment 1: Hello World Registry
A simple registry where users can store and retrieve personalized messages.

**Key Concepts:** Maps, principals, basic storage

### Assignment 2: Voting System
Create proposals and vote on them with one vote per user.

**Key Concepts:** Complex data structures, authorization, preventing double-voting

### Assignment 3: Timelock Wallet
Lock STX tokens that can only be withdrawn after a specified time.

**Key Concepts:** STX transfers, block-height conditions, time-based logic

### Assignment 4: Escrow Contract
Two-party escrow where buyer deposits and can release to seller or get refund.

**Key Concepts:** Multi-party authorization, state machines, financial flows

### Assignment 5: NFT Marketplace
List, buy, and manage NFT sales with marketplace fees.

**Key Concepts:** NFT traits, complex transactions, fee mechanics, custody

## Resources

- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [Clarity Playground](https://platform.hiro.so/projects)
- [SIP-009 NFT Standard](https://github.com/stacksgov/sips)
- [Stacks Documentation](https://docs.stacks.co)

## Grading Criteria

- **Functionality** (40%): Does the contract work as specified?
- **Code Quality** (25%): Is the code clean, well-organized, and properly commented?
- **Security** (20%): Are edge cases handled? No obvious vulnerabilities?
- **Testing** (15%): Are test cases comprehensive and well-documented?

Good luck with your assignments! 🚀
