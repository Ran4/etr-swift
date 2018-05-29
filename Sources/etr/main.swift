import Foundation

func fst<A, B>(_ ab: (A, B)) -> A {
    let (a, _) = ab
    return a
}

func snd<A, B>(_ ab: (A, B)) -> B {
    let (_, b) = ab
    return b
}

indirect enum Token: CustomStringConvertible {
    case Key(String)
    case TokenDict(dict: Dictionary<String, Token>)
    case List([Token])
    case TokenInt(Int)
    case TokenString(String)
    case As
    case Both
    case And
    case NameBinder(Token)
    case Bound(String, Token)
    
    static func from(_ inputValue: String) -> Token? {
        switch inputValue {
        case _ where inputValue.hasPrefix(":"): return .Key(inputValue)
        case _ where inputValue.hasPrefix("\"") && inputValue.hasSuffix("\""):
            return .TokenString(String(inputValue.dropFirst().dropLast()))
        case "as": return .As
        case "both": return .Both
        case "and": return .And
        case _: return nil
        }
    }
    
    var description: String {
        switch self {
        case let .Key(s): return s
        case let .TokenInt(i): return String(i)
        case let .TokenDict(d):
            var dictRepresentations: [String] = []
            for (key, value) in d {
                dictRepresentations.append("\(key) \(value)")
            }
            return "(dict \(dictRepresentations.joined(separator: " ")))"
        case let .List(tokens):
            let tokenDescriptions = tokens.map {token in token.description }.joined(separator: " ")
            return "(list \(tokenDescriptions))"
        case let .TokenString(s): return "\"" + s + "\""
        case .As: return "(as)"
        case .Both: return "(both)"
        case .And: return "(and)"
        case let .NameBinder(token): return "(namebinder \(token))"
        case let .Bound(key, token): return "(bound \(key) \(token))"
        }
    }
}

typealias Stack = [Token]
    
func evaluate(stack: Stack, token: Token) -> Stack {
    print("EVAL [ \(stack.map{$0.description}.joined(separator: " ")) ] \(token)")
    switch token {
    case .As:
        if let tokenFromStack = stack.last {
            return stack.dropLast() + [.NameBinder(tokenFromStack)]
        } else {
            print("WANING: 'As' statement with empty stack. Does nothing.")
        }
    case .Both:
        return stack + [.Both]
    case .And:
        return stack + [.And]
    case _:
        break
    // case 
    }
    
    if let currentStackToken = stack.last {
        switch currentStackToken {
        case .And:
            if case let prevToken? = stack.dropLast().last {
                return evaluate(stack: Array(stack.dropLast(2)), token: .List([prevToken, token]))
            } else {
                print("WANING: 'And' statement with empty stack. Does nothing.")
            }
        case .Both:
            if case .List = token { // fall-through
                print("'Both' got list, falling through")
                return evaluate(stack: Array(stack.dropLast()), token: token)
            } else {
                break
            }
        case let .Key(s):
            if case let .TokenDict(oldDict)? = stack.dropLast().last {
                // dict - Any - dict
                let newDict = [s: token]
                let mergedDict = oldDict.merging(newDict, uniquingKeysWith: snd)
                let newToken = Token.TokenDict(dict: mergedDict)
                return stack.dropLast(2) + [newToken]
            } else {
                // void - Any - dict
                let newToken = Token.TokenDict(dict: [s: token])
                return stack.dropLast() + [newToken]
            }
        case let .TokenDict(d1):
            switch token {
            case let .TokenDict(d2):
                // void - dict - dict
                print("dict eats dict -> update with new dict")
                let newDict = d1.merging(d2, uniquingKeysWith: { (v1, v2) in v2 })
                let newToken = Token.TokenDict(dict: newDict)
                return stack.dropLast() + [newToken]
            case _:
                break
            }
        case .As:
            return stack.dropLast() + [.NameBinder(token)]
        case let .NameBinder(tokenToBind):
            switch token {
            case let .Key(s):
                return stack.dropLast() + [.Bound(s, tokenToBind)]
            case let .List(tokenKeys):
                // Bind every token in the list
                var newStack: [Token] = Array(stack.dropLast())
                for tokenKey in tokenKeys {
                    newStack = evaluate(stack: newStack + [.NameBinder(tokenToBind)], token: tokenKey)
                }
                return newStack
            case _:
                print("Unrecognized last stack value in stack \(stack) for .NameBinder")
                break
            }
        case _:
            print("Unrecognized current stack token \(currentStackToken)")
            break
        }
    }
    
    return stack + [token]
}

func run(stack: Stack, tokens: [Token]) -> Stack {
    // print("STACK: \(stack)")
    if tokens.count == 0 {
        print("-> \(stack)")
        return stack
    }
    let token = tokens[0]
    print("-> \(stack)")
    let newStack = evaluate(stack: stack, token: token)
    return run(stack: newStack, tokens: Array(tokens.dropFirst()))
}

var stack = [Token]()

// var tokens: [Token] =
//     [
//         ":age", "\"Really old\"", "as", "both", ":person", "and", ":oldPerson",
//     ].map { Token.from($0)! }
// let finalStack = run(stack: stack, tokens: tokens)

func runCli() {
    func printHelp() {
        print("HELP GOES HERE")
    }

    while true {
        print("> ", terminator: "")
        if let line = readLine() {
            guard let token = Token.from(line) else {
                if line == "help" {
                    printHelp()
                } else {
                    print("Invalid token `\(line)`")
                }
                continue
            }
            
            stack = evaluate(stack: stack, token: token)
            print("-> \(stack)")
        } else {
            print("Couldn't read line, quitting...")
            break
        }
    }
}

runCli()

/// TODO: implement using [ETR definitions](etr_abnf_definitions.abnf)
let rawEtcLines: String = """
key:
    dict - Any - dict
    void - Any - dict
dict:
    void - dict - dict
as:
    void - Any - namebinder
namebinder:
    void - key - bound
both:
    void - list - bound
and:
    void - key - list
,:
    key - key - void
,:
    list - key - void
"""
