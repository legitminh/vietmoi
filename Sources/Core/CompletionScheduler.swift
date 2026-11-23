import Foundation

typealias CompletionSubmit = (@escaping () -> [String], @escaping ([String]) -> Void) -> Operation?

enum CompletionScheduler {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "sieuviet.completion"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    static func submit<Value>(_ work: @escaping () -> Value, receive: @escaping (Value) -> Void) -> Operation? {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation] in
            guard let operation = operation, !operation.isCancelled else { return }
            let values = work()
            guard !operation.isCancelled else { return }
            OperationQueue.main.addOperation { [weak operation] in
                guard operation?.isCancelled == false else { return }
                receive(values)
            }
        }
        queue.addOperation(operation)
        return operation
    }
}
