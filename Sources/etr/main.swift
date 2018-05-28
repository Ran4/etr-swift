import Foundation

func fst<A, B>(_ ab: (A, B)) -> A {
    let (a, _) = ab
    return a
}

func snd<A, B>(_ ab: (A, B)) -> B {
    let (_, b) = ab
    return b
}

struct Ets {
    let name: String
    let before: [String]
    let takes: [String]
    let becomes: [String]
    
    init(_ name: String, _ before: [String], _ takes: [String], _ becomes: [String]) {
        self.name = name
        self.before = before
        self.takes = takes
        self.becomes = becomes
    }
    
    static func from(rawLine: String) -> Ets? { // {{{
        let splitted = rawLine.split(separator: "-").map({String($0)})
        if splitted.count != 4 {
            print("Found \(splitted.count) values after splitting \(rawLine)" +
                  "into \(splitted), expected 4")
            return nil
        }
        
        let (rawName, rawBefore, rawTakes, rawBecomes) =
            (splitted[0], splitted[1], splitted[2], splitted[3])
        
        func list_from_string(_ s: String) -> [String] {
            let s = s.trimmingCharacters(in: .whitespaces)
            return s.split(separator: " ").map({String($0)})
        }
        
        return Ets(rawName.trimmingCharacters(in: .whitespaces),
                   list_from_string(rawBefore),
                   list_from_string(rawTakes),
                   list_from_string(rawBecomes))
    }
    
    static func from(rawLines: String) -> [Ets] {
        return rawLines.split(separator: "\n").map {
            Ets.from(rawLine: String($0))!
        }
    }// }}}
}


indirect enum Item: CustomStringConvertible {
    case Key(String)
    case ItemDict(dict: Dictionary<String, Item>)
    case List([Item])
    case ItemInt(Int)
    case ItemString(String)
    case As
    case Both
    case And
    case NameBinder(Item)
    case Bound(String, Item)
    
    static func from(_ inputValue: String) -> Item? {
        if inputValue.hasPrefix(":") {
            return .Key(inputValue)
        } else {
            if inputValue == "as" {
                return .As
            } else if inputValue == "both" {
                return .Both
            } else if inputValue == "and" {
                return .And
            } else {
                return .ItemString(inputValue)
            }
        }
    }
    
    var description: String {
        switch self {
            case let .Key(s): return s
            case let .ItemInt(i): return String(i)
            case let .ItemDict(d):
                var dictRepresentations: [String] = []
                for (key, value) in d {
                    dictRepresentations.append("\(key) \(value)")
                }
                return "(dict \(dictRepresentations.joined(separator: " ")))"
            case let .List(items):
                let itemDescriptions = items.map {item in item.description }.joined(separator: " ")
                return "(list \(itemDescriptions))"
            case let .ItemString(s): return "\"" + s + "\""
            case .As: return "(as)"
            case .Both: return "(both)"
            case .And: return "(and)"
            case let .NameBinder(item): return "(namebinder \(item))"
            case let .Bound(key, item): return "(bound \(key) \(item))"
        }
    }
}

typealias Stack = [Item]
    
func iterate(stack: Stack, item: Item) -> Stack {
    print("EVAL [ \(stack.map{$0.description}.joined(separator: " ")) ] \(item)")
    switch item {
    case .As:
        if let itemFromStack = stack.last {
            return stack.dropLast() + [.NameBinder(itemFromStack)]
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
    
    if let currentStackItem = stack.last {
        switch currentStackItem {
        case .And:
            if case let prevItem? = stack.dropLast().last {
                return iterate(stack: Array(stack.dropLast(2)), item: .List([prevItem, item]))
            } else {
                print("WANING: 'And' statement with empty stack. Does nothing.")
            }
        case .Both:
            if case .List = item { // fall-through
                print("'Both' got list, falling through")
                return iterate(stack: Array(stack.dropLast()), item: item)
            } else {
                break
            }
        case let .Key(s):
            if case let .ItemDict(oldDict)? = stack.dropLast().last {
                // dict - Any - dict
                let newDict = [s: item]
                let mergedDict = oldDict.merging(newDict, uniquingKeysWith: snd)
                let newItem = Item.ItemDict(dict: mergedDict)
                return stack.dropLast(2) + [newItem]
            } else {
                // void - Any - dict
                let newItem = Item.ItemDict(dict: [s: item])
                return stack.dropLast() + [newItem]
            }
            
        case let .ItemDict(d1):
            switch item {
            case let .ItemDict(d2):
                // void - dict - dict
                print("dict eats dict -> update with new dict")
                let newDict = d1.merging(d2, uniquingKeysWith: { (v1, v2) in v2 })
                let newItem = Item.ItemDict(dict: newDict)
                return stack.dropLast() + [newItem]
            case _:
                break
            }
        case .As:
            return stack.dropLast() + [.NameBinder(item)]
        case let .NameBinder(itemToBind):
            switch item {
            case let .Key(s):
                return stack.dropLast() + [.Bound(s, itemToBind)]
            case let .List(itemKeys):
                //TODO: fix this
                print("cool, got list of itemKeys \(itemKeys)")
                var newStack: [Item] = Array(stack)
                for itemKey in itemKeys {
                    newStack = iterate(stack: newStack + [.NameBinder(itemToBind)], item: itemKey)
                }
                return newStack
            case _:
                print("Unrecognized last stack value in stack \(stack) for .NameBinder")
                break
            }
        case _:
            print("Unrecognized current stack item \(currentStackItem)")
            break
        }
    }
    
    return stack + [item]
}

func run(stack: Stack, items: [Item]) -> Stack {
    // print("STACK: \(stack)")
    if items.count == 0 {
        return stack
    }
    let item = items[0]
    // print("\(item)")
    let newStack = iterate(stack: stack, item: item)
    return run(stack: newStack, items: Array(items.dropFirst()))
}


let stack = [Item]()
           
let items: [Item] = [
    // Item.from(":name")!,
    // Item.from("Something")!,
    Item.from(":age")!,
    Item.from("Really old")!,
    Item.from("as")!,
    Item.from("both")!,
    Item.from(":person")!,
    Item.from("and")!,
    Item.from(":lol")!,
]

let finalStack = run(stack: stack, items: items)

// stack = iterate(stack: stack, item: item)

// item = 
// print("STACK: \(stack)\nITEM: \(item)\n")


let rawEtcLines: String = """
    key - dict - Any - dict
    key - void - Any - dict
    dict - void - dict - dict
    as - void - Any - namebinder
    namebinder - void - key - bound
    both - void - list - bound
    and - void - key - list
    , - key - key - void
    , - list - key - void
    """
    
/// TODO: implement using [ETR definitions](etr_abnf_definitions.abnf)
let rawEtcLines2: String = """
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
    
var etss = Ets.from(rawLines: rawEtcLines)
var etsDict = [String: Ets]()
for ets in etss {
    etsDict[ets.name] = ets
}

// print(etsDict)
