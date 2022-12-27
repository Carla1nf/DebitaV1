// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./NFT.sol";

contract DebitaV1 is ERC1155Holder {
    error notEnoughFunds();
    error requirementsNotFull();

    event LenderOfferCreated(uint256 id, address _owner);
    event LenderOfferDeleted(uint256 id, address _owner);
    event LenderAcepted(uint256 LenderID, uint256 LoanId);
    event CollateralOfferCreated(uint256 id, address _owner);
    event CollateralOfferDeleted(uint256 id, address _owner);
    event CollateralAccepted(uint256 LenderID, uint256 LoanId);

    address owner;
    uint256 Lender_OF_ID;
    uint256 Collateral_OF_ID;
    uint256 LOAN_ID;
    address NFT_CONTRACT;
    uint32 NFT_ID;

    struct LenderOInfo {
        address LenderToken;
        address[] wantedCollateralTokens;
        uint256[] wantedCollateralAmount;
        uint256 LenderAmount;
        uint256 interest;
        uint256 timelap;
        uint256 paymentCount;
        bytes32 root;
        address owner;
    }

    struct CollateralOInfo {
        address wantedLenderToken;
        address[] collaterals;
        uint256[] collateralAmount;
        uint256 wantedLenderAmount;
        uint256 interest;
        uint256 timelap;
        uint256 paymentCount;
        bytes32 root;
        address owner;
    }

    struct LoanInfo {
        uint32 collateralOwnerID;
        uint32 LenderOwnerId;
        address LenderToken;
        uint256 LenderAmount;
        address[] collaterals;
        uint256[] collateralAmount;
        uint256 timelap;
        uint256 paymentCount;
        uint256 paymentsPaid;
        uint256 paymentAmount;
        uint256 deadline;
        uint256 deadlineNext;
        bool executed;
    }

    // Lender ID => All Info About the Offer
    mapping(uint256 => LenderOInfo) public LendersOffers;
    // Collateral ID => All Info About the Collateral
    mapping(uint256 => CollateralOInfo) public CollateralOffers;
    // Loan ID => All Info about the Loan
    mapping(uint256 => LoanInfo) public Loans;
    // NFT ID => Loan ID
    mapping(uint256 => uint256) public loansByNFt;
    // NFT ID => CLAIMEABLE DEBT
    mapping(uint256 => uint256) public claimeableDebt;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    function createLenderOption(
        address _LenderToken,
        address[] memory _wantedCollateralTokens,
        uint256[] memory _wantedCollateralAmount,
        uint256 _LenderAmount,
        uint256 _interest,
        uint256 _timelap,
        uint256 _paymentCount,
        bytes32 _root
    ) public payable {
        if (
            _timelap < 1 days ||
            _timelap > 365 days ||
            _wantedCollateralTokens.length != _wantedCollateralAmount.length ||
            _LenderAmount == 0
        ) {
            revert();
        }

        if (_LenderToken == address(0x0)) {
            require(msg.value >= _LenderAmount);
        } else {
            IERC20 B_Token = IERC20(_LenderToken);
            B_Token.transferFrom(msg.sender, address(this), _LenderAmount);
        }

        Lender_OF_ID++;
        LenderOInfo memory lastLender = LenderOInfo({
            LenderToken: _LenderToken,
            wantedCollateralTokens: _wantedCollateralTokens,
            wantedCollateralAmount: _wantedCollateralAmount,
            LenderAmount: _LenderAmount,
            interest: _interest,
            timelap: _timelap,
            paymentCount: _paymentCount,
            root: _root,
            owner: msg.sender
        });
        LendersOffers[Lender_OF_ID] = lastLender;
        emit LenderOfferCreated(Lender_OF_ID, msg.sender);
    }

    // Cancel Lender Offer
    function cancelLenderOffer(uint256 id) public {
        LenderOInfo memory _LenderINFO = LendersOffers[id];
        if (_LenderINFO.owner != msg.sender) {
            revert();
        }
        delete LendersOffers[id];
        IERC20 B_TOKEN = IERC20(_LenderINFO.LenderToken);
        B_TOKEN.transfer(msg.sender, _LenderINFO.LenderAmount);
        emit LenderOfferDeleted(id, msg.sender);
    }

    // User A offers to provide some collateral, such as a valuable asset, to User B in exchange for the loan. User B agrees to lend the money to User A under the condition that User A puts up the collateral as security for the loan.

    function createCollateralOffer(
        address _wantedLenderToken,
        address[] memory collateralTokens,
        uint256[] memory collateralAmount,
        uint256 _wantedLenderAmount,
        uint256 _interest,
        uint256 _timelap,
        uint256 _paymentCount,
        bytes32 _root
    ) public payable {
        if (
            _timelap < 1 days ||
            _timelap > 365 days ||
            collateralTokens.length != collateralAmount.length ||
            _wantedLenderAmount == 0 ||
            _paymentCount > 500
        ) {
            revert();
        }
        uint256 amountWEI;
        for (uint256 i; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == address(0x0)) {
                amountWEI += collateralAmount[i];
            } else {
                IERC20 ERC20_TOKEN = IERC20(collateralTokens[i]);
                ERC20_TOKEN.transferFrom(
                    msg.sender,
                    address(this),
                    collateralAmount[i]
                );
            }
        }
        require(msg.value >= amountWEI, "Not Enough ETHER");

        Collateral_OF_ID++;

        CollateralOInfo memory lastCollateral = CollateralOInfo({
            wantedLenderToken: _wantedLenderToken,
            collaterals: collateralTokens,
            collateralAmount: collateralAmount,
            wantedLenderAmount: _wantedLenderAmount,
            interest: _interest,
            timelap: _timelap,
            paymentCount: _paymentCount,
            root: _root,
            owner: msg.sender
        });
        CollateralOffers[Collateral_OF_ID] = lastCollateral;
        emit CollateralOfferCreated(Collateral_OF_ID, msg.sender);
    }

    function cancelCollateralOffer(uint256 _id) public {
        CollateralOInfo memory collateralInfo = CollateralOffers[_id];
        require(collateralInfo.owner == msg.sender, "Not the owner");
        delete CollateralOffers[_id];
        for (uint256 i; i < collateralInfo.collateralAmount.length; i++) {
            IERC20 token = IERC20(collateralInfo.collaterals[i]);
            token.transfer(msg.sender, collateralInfo.collateralAmount[i]);
        }
        emit CollateralOfferDeleted(_id, msg.sender);
    }

    function acceptCollateralOffer(uint256 _id, bytes32[] memory proof)
        public
        payable
    {
        CollateralOInfo memory collateralInfo = CollateralOffers[_id];
        require(
            collateralInfo.owner != address(0x0),
            "Deleted/Non-Existant Offer"
        );
        // Check Whitelist
        if (collateralInfo.root != 0x0) {
            bytes32 _leaf = keccak256(abi.encodePacked(msg.sender));
            bool Whitelisted = MerkleProof.verify(
                proof,
                collateralInfo.root,
                _leaf
            );
            require(Whitelisted, "You are not in the whitelist");
        }

        delete CollateralOffers[_id];

        // Send Tokens to Collateral Owner

        if (collateralInfo.wantedLenderToken == address(0x0)) {
            require(
                msg.value >= collateralInfo.wantedLenderAmount,
                "Not Enough Ether"
            );
            (bool success, ) = collateralInfo.owner.call{
                value: collateralInfo.wantedLenderAmount
            }("");
            require(success, "Transaction Error");
        } else {
            IERC20 wantedToken = IERC20(collateralInfo.wantedLenderToken);
            wantedToken.transferFrom(
                msg.sender,
                collateralInfo.owner,
                collateralInfo.wantedLenderAmount
            );
        }

        // Update States & Mint NFTS
        NFT_ID += 2;
        LOAN_ID++;
        Ownerships ownershipContract = Ownerships(NFT_CONTRACT);
        for (uint256 i; i < 2; i++) {
            ownershipContract.mint();
            if (i == 0) {
                ownershipContract.safeTransferFrom(
                    address(this),
                    msg.sender,
                    NFT_ID - 1,
                    1,
                    ""
                );
                loansByNFt[NFT_ID - 1] = LOAN_ID;
            } else {
                ownershipContract.safeTransferFrom(
                    address(this),
                    collateralInfo.owner,
                    NFT_ID,
                    1,
                    ""
                );
                loansByNFt[NFT_ID] = LOAN_ID;
            }
            // Transfer to new owners
        }
        // Save Loan Info
        uint256 paymentPerTime;
        if (collateralInfo.paymentCount > 0) {
            paymentPerTime =
                ((collateralInfo.wantedLenderAmount /
                    collateralInfo.paymentCount) *
                    (100 + collateralInfo.interest)) /
                100;
        } else {
            paymentPerTime = ((collateralInfo.wantedLenderAmount *
                (100 + collateralInfo.interest)) / 100);
        }

        uint256 globalDeadline = (collateralInfo.paymentCount *
            collateralInfo.timelap) + block.timestamp;
        uint256 nextDeadline = block.timestamp + collateralInfo.timelap;
        Loans[LOAN_ID] = LoanInfo({
            collateralOwnerID: NFT_ID,
            LenderOwnerId: NFT_ID - 1,
            LenderToken: collateralInfo.wantedLenderToken,
            LenderAmount: collateralInfo.wantedLenderAmount,
            collaterals: collateralInfo.collaterals,
            collateralAmount: collateralInfo.collateralAmount,
            timelap: collateralInfo.timelap,
            paymentCount: collateralInfo.paymentCount,
            paymentsPaid: 0,
            paymentAmount: paymentPerTime,
            deadline: globalDeadline,
            deadlineNext: nextDeadline,
            executed: false
        });
        emit CollateralAccepted(_id, LOAN_ID);
    }

    function acceptLenderOffer(uint256 id, bytes32[] memory proof)
        public
        payable
    {
        LenderOInfo memory lenderInfo = LendersOffers[id];
        require(lenderInfo.owner != address(0x0), "Deleted/Expired Offer");
        // Check Whitelist
        if (lenderInfo.root != 0x0) {
            bytes32 _leaf = keccak256(abi.encodePacked(msg.sender));
            bool Whitelisted = MerkleProof.verify(
                proof,
                lenderInfo.root,
                _leaf
            );
            require(Whitelisted, "You are not in the whitelist");
        }

        delete LendersOffers[id];
        uint256 WEIamount;

        // Send Collaterals to this contract
        for (uint256 i; i < lenderInfo.wantedCollateralTokens.length; i++) {
            if (lenderInfo.wantedCollateralTokens[i] == address(0x0)) {
                WEIamount += lenderInfo.wantedCollateralAmount[i];
            } else {
                IERC20 wantedToken = IERC20(
                    lenderInfo.wantedCollateralTokens[i]
                );
                wantedToken.transferFrom(
                    msg.sender,
                    address(this),
                    lenderInfo.wantedCollateralAmount[i]
                );
            }
        }

        require(msg.value >= WEIamount, "Not enough Ether");
        // Update States & Mint NFTS
        NFT_ID += 2;
        LOAN_ID++;
        Ownerships ownershipContract = Ownerships(NFT_CONTRACT);

        for (uint256 i; i < 2; i++) {
            ownershipContract.mint();
            if (i == 0) {
                ownershipContract.safeTransferFrom(
                    address(this),
                    lenderInfo.owner,
                    NFT_ID - 1,
                    1,
                    ""
                );
                loansByNFt[NFT_ID - 1] = LOAN_ID;
            } else {
                ownershipContract.safeTransferFrom(
                    address(this),
                    msg.sender,
                    NFT_ID,
                    1,
                    ""
                );
                loansByNFt[NFT_ID] = LOAN_ID;
            }
        }
        // Save Loan Info
        uint256 paymentPerTime;
        if (lenderInfo.paymentCount > 0) {
            paymentPerTime =
                ((lenderInfo.LenderAmount / lenderInfo.paymentCount) *
                    (100 + lenderInfo.interest)) /
                100;
        } else {
            paymentPerTime = ((lenderInfo.LenderAmount *
                (100 + lenderInfo.interest)) / 100);
        }

        uint256 globalDeadline = (lenderInfo.paymentCount *
            lenderInfo.timelap) + block.timestamp;
        uint256 nextDeadline = block.timestamp + lenderInfo.timelap;
        Loans[LOAN_ID] = LoanInfo({
            collateralOwnerID: NFT_ID,
            LenderOwnerId: NFT_ID - 1,
            LenderToken: lenderInfo.LenderToken,
            LenderAmount: lenderInfo.LenderAmount,
            collaterals: lenderInfo.wantedCollateralTokens,
            collateralAmount: lenderInfo.wantedCollateralAmount,
            timelap: lenderInfo.timelap,
            paymentCount: lenderInfo.paymentCount,
            paymentsPaid: 0,
            paymentAmount: paymentPerTime,
            deadline: globalDeadline,
            deadlineNext: nextDeadline,
            executed: false
        });
        // Send Loan to the owner of the collateral
        if (lenderInfo.LenderToken == address(0x0)) {
            (bool success, ) = msg.sender.call{value: lenderInfo.LenderAmount}(
                ""
            );
            require(success, "Transaction Error");
        } else {
            IERC20 lenderToken = IERC20(lenderInfo.LenderToken);
            lenderToken.transfer(msg.sender, lenderInfo.LenderAmount);
        }

        emit LenderAcepted(id, LOAN_ID);
    }

    function payDebt(uint256 id) public payable {
        LoanInfo memory loan = Loans[id];
        Ownerships ownerContract = Ownerships(NFT_CONTRACT);

        if (
            loan.deadline < block.timestamp ||
            ownerContract.balanceOf(msg.sender, loan.collateralOwnerID) != 1 ||
            loan.paymentsPaid == loan.paymentCount ||
            loan.executed == true
        ) {
            revert();
        }

        if (loan.LenderToken == address(0x0)) {
            require(msg.value >= loan.paymentAmount);
        } else {
            IERC20 lenderToken = IERC20(loan.LenderToken);
            lenderToken.transferFrom(
                msg.sender,
                address(this),
                loan.paymentAmount
            );
        }

        claimeableDebt[loan.LenderOwnerId] += loan.paymentAmount;
        loan.paymentsPaid += 1;
        loan.deadlineNext += loan.timelap;
        Loans[id] = loan;
    }

    function claimCollateralasLender(uint256 id) public {
        LoanInfo memory loan = Loans[id];
        Ownerships ownerContract = Ownerships(NFT_CONTRACT);

        if (
            ownerContract.balanceOf(msg.sender, loan.LenderOwnerId) != 1 ||
            loan.deadlineNext > block.timestamp ||
            loan.paymentCount == loan.paymentsPaid ||
            loan.executed == true
        ) {
            revert();
        }
        loan.executed = true;
        uint256 WEIamount;
        for (uint256 i; i < loan.collaterals.length; i++) {
            if (loan.collaterals[i] == address(0x0)) {
                WEIamount += loan.collateralAmount[i];
            } else {
                IERC20 token = IERC20(loan.collaterals[i]);
                token.transfer(msg.sender, loan.collateralAmount[i]);
            }
        }
        (bool success, ) = msg.sender.call{value: WEIamount}("");
        require(success);
        Loans[id] = loan;
    }

    function claimCollateralasBorrower(uint256 id) public {
        LoanInfo memory loan = Loans[id];
        Ownerships ownerContract = Ownerships(NFT_CONTRACT);
        if (
            ownerContract.balanceOf(msg.sender, loan.collateralOwnerID) != 1 ||
            loan.paymentCount != loan.paymentsPaid ||
            loan.executed == true
        ) {
            revert();
        }

        loan.executed = true;
        uint256 WEIamount;
        for (uint256 i; i < loan.collaterals.length; i++) {
            if (loan.collaterals[i] == address(0x0)) {
                WEIamount += loan.collateralAmount[i];
            } else {
                IERC20 token = IERC20(loan.collaterals[i]);
                token.transfer(msg.sender, loan.collateralAmount[i]);
            }
        }
        (bool success, ) = msg.sender.call{value: WEIamount}("");
        require(success);
        Loans[id] = loan;
    }

    function setNFTContract(address _newAddress) public onlyOwner {
        NFT_CONTRACT = _newAddress;
    }

}
