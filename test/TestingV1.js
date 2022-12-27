const { assert } = require("chai");
const { time } = require("@openzeppelin/test-helpers");

const DebitaV = artifacts.require("DebitaV1");
const Token = artifacts.require("DebitaERC20");
const Ownerships = artifacts.require("Ownerships");

require("chai")
    .use(require("chai-as-promised"))
    .should()

const TOKENS_MINTED = "1000000000000000000000";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const Timelap_10_TIMES = 86400000;



contract("Debita V1", (accounts) => {
    it("Deploy Contract", async () => {
        const debita = await DebitaV.deployed();
        await Token.deployed();

    }),

        it("Mint Tokens", async () => {
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await token.mint(TOKENS_MINTED);
            const totalTokens = await token.balanceOf(accounts[0]);
            assert.equal(totalTokens, TOKENS_MINTED, "Not correct Amount");
        }),

        it("Create Lender Option -- TEST ERC20 & NATIVE TOKENS", async () => {
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await token.approve(
                debita.address,
                10000
            );
            await debita.createLenderOption(
                token.address,
                [ZERO_ADDRESS],
                [0],
                1000,
                0,
                8640000,
                0,
                "0x0"
            );

            await debita.createLenderOption(
                ZERO_ADDRESS,
                [ZERO_ADDRESS],
                [0],
                1000,
                0,
                8640000,
                0,
                "0x0"
                , { value: 1000 });

            await debita.createLenderOption(
                ZERO_ADDRESS,
                [ZERO_ADDRESS, ZERO_ADDRESS],
                [0],
                1000,
                0,
                8640000,
                0,
                "0x0"
                , { value: 1000 }).should.be.rejected;

            await debita.createLenderOption(
                ZERO_ADDRESS,
                [ZERO_ADDRESS],
                [0],
                1000,
                0,
                8640000,
                0,
                "0x0"
                , { value: 0 }).should.be.rejected;

            await debita.createLenderOption(
                token.address,
                [ZERO_ADDRESS],
                [1000],
                1000,
                0,
                8640000,
                0,
                "0x0"
            );
            const firstLender = await debita.LendersOffers(1);
            assert.equal(firstLender.owner, accounts[0], "Not same owner");
        }),
        it("Cancel Lender Option", async () => {
            const debita = await DebitaV.deployed();
            await debita.cancelLenderOffer(
                1, { from: accounts[2] }
            ).should.be.rejected;
            await debita.cancelLenderOffer(
                1)
            await debita.cancelLenderOffer(
                1).should.be.rejected;
            const firstLender = await debita.LendersOffers(1);
            assert.equal(firstLender.owner, ZERO_ADDRESS, "Did not Delete");


        }),

        it("Testing Collateral Offer -- OFFERING ETH & ERC20 // ERC20 & ERC20 // ETH & ETH AS COLLATERAL", async () => {
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await token.mint(TOKENS_MINTED);
            await token.approve(
                debita.address,
                20000
            );
            // ETH & ERC20
            await debita.createCollateralOffer(
                ZERO_ADDRESS,
                [ZERO_ADDRESS, token.address],
                [10000, 10000],
                20000,
                2,
                8640000,
                0,
                "0x0",
                { value: 10000 }
            );
            // ERC20 & ERC20
            await debita.createCollateralOffer(
                ZERO_ADDRESS,
                [token.address, token.address],
                [100, 100],
                20000,
                2,
                8640000,
                0,
                "0x0"
            );
            // ETH & ETH
            await debita.createCollateralOffer(
                ZERO_ADDRESS,
                [ZERO_ADDRESS, ZERO_ADDRESS],
                [100, 100],
                20000,
                2,
                8640000,
                0,
                "0x0",
                { value: 200 }
            );

        }),
        it("Cancel Collateral Reject Collateral Offers with wrong params", async () => {
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await debita.cancelCollateralOffer(
                2
            );
            await debita.cancelCollateralOffer(
                2
            ).should.be.rejected;
            await debita.cancelCollateralOffer(3, { from: accounts[6] }).should.be.rejected
            await token.mint(TOKENS_MINTED);
            await token.approve(
                debita.address,
                20000
            );
            await debita.createCollateralOffer(
                ZERO_ADDRESS,
                [ZERO_ADDRESS, token.address],
                [10000, 10000],
                20000,
                2,
                8640000,
                0,
                { value: 9000 }
            ).should.be.rejected;
            await debita.createCollateralOffer(
                ZERO_ADDRESS,
                [ZERO_ADDRESS, ZERO_ADDRESS],
                [10000, 10000],
                20000,
                2,
                8640000,
                0,
                { value: 11000 }
            ).should.be.rejected;
        }),
        it("Accept Collateral Offer", async () => {
            const ownershipContract = await Ownerships.deployed();
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await debita.setNFTContract(ownershipContract.address);
            const balanceBefore = await web3.eth.getBalance(accounts[0]);
            await debita.acceptCollateralOffer(3, ["0x0"], { value: 200000, from: accounts[3], gas: 2000000 });
            const balanceAfter = await web3.eth.getBalance(accounts[0]);
            const ownerLender = await ownershipContract.balanceOf(accounts[3], 1);
            const ownerCollateral = await ownershipContract.balanceOf(accounts[0], 2);
            assert.equal(ownerLender, 1, "Not the owner");
            assert.equal(ownerCollateral, 1, "Not the owner");
            assert.equal((balanceAfter - balanceBefore) > 16000, true, "Borrow Money is not at borrower Account");

        }),
        it("Accept Lender Offer", async () => {
            const ownershipContract = await Ownerships.deployed();
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            const BalanceBeforeBorrower = await token.balanceOf(accounts[3]);
            const balanceBefore = await web3.eth.getBalance(debita.address);
            await debita.acceptLenderOffer(3, ["0x0"], { from: accounts[3], value: 1000 });
            const balanceAfter = await web3.eth.getBalance(debita.address);
            const BalanceAfterBorrower = await token.balanceOf(accounts[3]);
            const ownerLender = await ownershipContract.balanceOf(accounts[0], 3);
            const ownerCollateral = await ownershipContract.balanceOf(accounts[3], 4);
            assert.equal(balanceAfter - balanceBefore, 1000, "Not 1000");
            assert.equal(ownerLender, 1, "Not the owner");
            assert.equal(ownerCollateral, 1, "Not the owner"); assert.equal(BalanceAfterBorrower - BalanceBeforeBorrower, 1000, "Borrowing Amount");
        }),

        it("Testing Whitelist on Lender & Collateral Offer", async () => {
            const ownershipContract = await Ownerships.deployed();
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await token.approve(
                debita.address,
                300000
            );
            await debita.createLenderOption(
                token.address,
                [ZERO_ADDRESS],
                [1000],
                100000,
                0,
                8640000,
                2,
                "0x9603747680110ea99af10a4ad287ebde6e3a5cc9915589ae3d1ee1d0b0cf5cc2" // Root For Merkle Tree
            );

            await debita.createLenderOption(
                token.address,
                [ZERO_ADDRESS, ZERO_ADDRESS],
                [1000, 1000],
                100000,
                0,
                8640000,
                0,
                "0x9603747680110ea99af10a4ad287ebde6e3a5cc9915589ae3d1ee1d0b0cf5cc2" // Root For Merkle Tree
            );
            await debita.acceptLenderOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[6] }
            ).should.be.rejected

            await debita.acceptLenderOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[2], value: 1000 }
            )
            await debita.acceptLenderOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[2], value: 1000 }).should.be.rejected;

            await debita.acceptLenderOffer(
                5, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[2], value: 1001 }
            ).should.be.rejected
            await debita.createCollateralOffer(
                token.address,
                [ZERO_ADDRESS, ZERO_ADDRESS],
                [1000, 1000],
                100000,
                0,
                8640000,
                2,
                "0x9603747680110ea99af10a4ad287ebde6e3a5cc9915589ae3d1ee1d0b0cf5cc2" // Root For Merkle Tree
                , { value: 2000 });
            await token.mint(TOKENS_MINTED, { from: accounts[2] });
            await token.approve(debita.address, TOKENS_MINTED, { from: accounts[2] });

            await debita.acceptCollateralOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[6] }
            ).should.be.rejected;

            await debita.acceptCollateralOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a042'
            ], { from: accounts[2] }
            ).should.be.rejected;

            await debita.acceptCollateralOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[2] }
            );

            await debita.acceptCollateralOffer(
                4, [
                '0x1461a2ebc6a01464593c2b4527dd41054d9b262a779d309c47b5f50c7415a16d',
                '0x33e3b18a5b979808729f0e94590322297daf15a030e7aeb70e8b8a53bc57a04f'
            ], { from: accounts[2] }
            ).should.be.rejected;
        }),

        it("Testing Paying Debt & Claiming Collateral", async () => {
            const ownershipContract = await Ownerships.deployed();
            const debita = await DebitaV.deployed();
            const token = await Token.deployed();
            await debita.payDebt(4);
            await debita.claimCollateralasBorrower(4).should.be.rejected;
            await debita.claimCollateralasLender(4, { from: accounts[2] }).should.be.rejected;
            await debita.payDebt(4);
            await debita.claimCollateralasBorrower(4);
            await debita.payDebt(3, {from: accounts[2]});
            await debita.claimCollateralasLender(3).should.be.rejected;
            await time.increase(Timelap_10_TIMES);
            await debita.claimCollateralasLender(3);

            // Acelarate Block and try claiming collateral as Borrower
  
        })

})