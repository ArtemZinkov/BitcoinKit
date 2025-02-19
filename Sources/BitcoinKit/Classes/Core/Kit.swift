import Foundation
import BitcoinCore
import HdWalletKit
import Hodler
import HsToolKit

public class Kit: AbstractKit {
    private static let heightInterval = 2016                                    // Default block count in difficulty change circle ( Bitcoin )
    private static let targetSpacing = 10 * 60                                  // Time to mining one block ( 10 min. Bitcoin )
    private static let maxTargetBits = 0x1d00ffff                               // Initially and max. target difficulty for blocks

    private static let name = "BitcoinKit"

    public enum NetworkType: String, CaseIterable {
        case mainNet, testNet, regTest
        
        public var network: INetwork {
            switch self {
            case .mainNet:
                return MainNet()
                
            case .testNet:
                return TestNet()
                
            case .regTest:
                return RegTest()
            }
        }
    }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    public convenience init(seed: Data, purpose: Purpose, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet, confirmationsThreshold: Int = 6, logger: Logger?, watchOnlyTransactionSigner: TransactionSigner?) throws {
        let version: HDExtendedKeyVersion
        switch purpose {
        case .bip32: version = .xprv
        case .bip44: version = .xprv
        case .bip49: version = .yprv
        case .bip84: version = .zprv
        case .bip86: version = .xprv
        }
        let masterPrivateKey = HDPrivateKey(seed: seed, xPrivKey: version.rawValue)

        try self.init(extendedKey: .private(key: masterPrivateKey),
                purpose: purpose,
                walletId: walletId,
                syncMode: syncMode,
                networkType: networkType,
                confirmationsThreshold: confirmationsThreshold,
                logger: logger,
                watchOnlyTransactionSigner: watchOnlyTransactionSigner)
    }

    public init(extendedKey: HDExtendedKey, purpose: Purpose, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet, confirmationsThreshold: Int = 6, logger: Logger?, watchOnlyTransactionSigner: TransactionSigner?) throws {
        let network = networkType.network
        let logger = logger ?? Logger(minLogLevel: .verbose)

        let initialSyncApi: ISyncTransactionApi?
        switch networkType {
            case .mainNet:
                initialSyncApi = BlockchainComApi(url: "https://blockchain.info", hsUrl: "https://api.blocksdecoded.com/v1/blockchains/bitcoin", logger: logger)
            case .testNet:
                initialSyncApi = BCoinApi(url: "https://btc-testnet.horizontalsystems.xyz/api", logger: logger)
            case .regTest:
                initialSyncApi = nil
        }

        let databaseFilePath = try DirectoryHelper.directoryURL(for: Kit.name).appendingPathComponent(Kit.databaseFileName(walletId: walletId, networkType: networkType, purpose: purpose, syncMode: syncMode)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)

        let paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
        let scriptConverter = ScriptConverter()
        let bech32AddressConverter = SegWitBech32AddressConverter(prefix: network.bech32PrefixPattern, scriptConverter: scriptConverter)
        let base58AddressConverter = Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash)

        let bitcoinCoreBuilder = BitcoinCoreBuilder(logger: logger)

        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let blockHelper = BlockValidatorHelper(storage: storage)

        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: blockHelper, heightInterval: Kit.heightInterval, targetTimespan: Kit.heightInterval * Kit.targetSpacing, maxTargetBits: Kit.maxTargetBits))
            blockValidatorChain.add(blockValidator: BitsValidator())
        case .regTest, .testNet:
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: blockHelper, heightInterval: Kit.heightInterval, targetTimespan: Kit.heightInterval * Kit.targetSpacing, maxTargetBits: Kit.maxTargetBits))
            blockValidatorChain.add(blockValidator: LegacyTestNetDifficultyValidator(blockHelper: blockHelper, heightInterval: Kit.heightInterval, targetSpacing: Kit.targetSpacing, maxTargetBits: Kit.maxTargetBits))
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let hodler = HodlerPlugin(addressConverter: bitcoinCoreBuilder.addressConverter, blockMedianTimeHelper: BlockMedianTimeHelper(storage: storage), publicKeyStorage: storage)

        let bitcoinCore = try bitcoinCoreBuilder
                .set(network: network)
                .set(initialSyncApi: initialSyncApi)
                .set(paymentAddressParser: paymentAddressParser)
                .set(walletId: walletId)
                .set(confirmationsThreshold: confirmationsThreshold)
                .set(peerSize: 10)
                .set(syncMode: syncMode)
                .set(storage: storage)
                .set(blockValidator: blockValidatorSet)
                .add(plugin: hodler)
                .set(purpose: purpose)
                .set(extendedKey: extendedKey)
                .set(watchOnlyTransactionSigner: watchOnlyTransactionSigner)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore

        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        switch purpose {
        case .bip44, .bip32:
            bitcoinCore.add(restoreKeyConverter: Bip44RestoreKeyConverter(addressConverter: base58AddressConverter))
            bitcoinCore.add(restoreKeyConverter: Bip49RestoreKeyConverter(addressConverter: base58AddressConverter))
            bitcoinCore.add(restoreKeyConverter: Bip84RestoreKeyConverter(addressConverter: bech32AddressConverter))
            bitcoinCore.add(restoreKeyConverter: hodler)
        case .bip49:
            bitcoinCore.add(restoreKeyConverter: Bip49RestoreKeyConverter(addressConverter: base58AddressConverter))
        case .bip84:
            bitcoinCore.add(restoreKeyConverter: Bip84RestoreKeyConverter(addressConverter: bech32AddressConverter))
        case .bip86:
            bitcoinCore.add(restoreKeyConverter: Bip86RestoreKeyConverter(addressConverter: bech32AddressConverter))
        }
    }

}

extension Kit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: Kit.name, except: walletIdsToExclude)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType, purpose: Purpose, syncMode: BitcoinCore.SyncMode) -> String {
        "\(walletId)-\(networkType.rawValue)-\(purpose.description)-\(syncMode)"
    }

}
