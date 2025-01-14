module Filter (
Filter,Filtered,
filters,
spaceFilter,
replaceAll,replaceAll',
filterAll,filterAll',
unfilterAll,unfilterAll',
prepSeqs,prepWords,prepAksaras,
filterSearch,
filterReplace
)
where

import Data.List (foldl')
import Data.Array ((!))
import Text.Regex.PCRE ((=~), MatchText)
import Data.String.Unicode (unicodeToXmlEntity)
import qualified Data.List.Split as S (split, condense, keepDelimsR, oneOf)
import Data.Fasta.String.Types (FastaSequence(..))
import Transcribe (transliterateString, splitAksaras, splitGlyphs, slp1', iast2slp1')

type ReplaceFn = MatchText String -> String

type Filtered = (ReplaceFn, [MatchText String])

data Filter = Filter
    {filterSearch :: String,
     filterReplace :: ReplaceFn,
     filterDesc :: String
    }

filters = [
    Filter {
        filterDesc = "valapalagilaka",
        filterSearch = "&#7769;",
        filterReplace = (const "r")
    },
    Filter {
        filterDesc = "short e",
        filterSearch = "&#7869;",
        filterReplace = (const "e")
    },
    Filter {
        filterDesc = "short o",
        filterSearch = "&#245;",
        filterReplace = (const "o")
    },
    Filter {
        filterDesc = "pṛṣṭhamātrā e",
        filterSearch = "&#234;",
        filterReplace = (const "e")
    },
    Filter {
        filterDesc = "pṛṣṭhamātrā o",
        filterSearch = "&#244;",
        filterReplace = (const "o")
    },
    Filter {
        filterDesc = "pṛṣṭhamātrā ai",
        filterSearch = "a&#238;",
        filterReplace = (const "E")
    },
    Filter {
        filterDesc = "pṛṣṭhamātrā au",
        filterSearch = "a&#251;",
        filterReplace = (const "O")
    },
    Filter {
        filterDesc = "candrabindu",
        filterSearch = "m&#784;",
        filterReplace = (const "M")
    },
    Filter {
        filterDesc = "oṃkāras",
        filterSearch = "o&#774[35];",
        filterReplace = (const "oM")
    },
    Filter {
        filterDesc = "non-ASCII characters",
        filterSearch ="&#\\d+;",
        filterReplace = (const "")
    },
    Filter {
        filterDesc = "additional punctuation",
        filterSearch = "[()\\[\\],;?!|_\\-=+\\d.\"\\\\/]+",
        filterReplace = (const "")
    },
    Filter {
        filterDesc = "geminated aspirated consonants",
        filterSearch = "(?:kK|gG|cC|jJ|wW|qQ|tT|dD|pP|bB)",
        filterReplace = (\mt -> tail . fst $ mt ! 0)
    },
    Filter {
        filterDesc = "geminated m after h",
        filterSearch = "(?:Mhm|hmm)",
        filterReplace = (const "hm")
    },
    Filter {
        filterDesc = "geminated t",
        filterSearch = "(?<=[rfi]|p[aA])tt|tt(?=[rvy]\\S)",
        filterReplace = (const "t")
    },
    Filter { 
        filterSearch = "([rf]\\s*)([kgcjwqdpbRnmyvl])\\2{1,2}", 
        filterReplace = (\mt -> (fst $ mt ! 1) ++ (fst $ mt ! 2)),
        filterDesc = "geminated consonants after r"
    },
    Filter {
        filterDesc = "final nasal variants",
        filterSearch = "(?:M[lSs]|nn)(?!\\S)",
        filterReplace = (const "n")
    },
    
    Filter {
        filterDesc = "internal nasal variants",
        filterSearch = "[mnNYR](?=[pPbBmdDtTnwWqQcCjJkKgG])",
        filterReplace = (const "M")
    },
    {-
    Filter {
        filterDesc = "internal m",
        filterSearch = "M(?=[pPbBm])",
        filterReplace = (const "m")
    },
    Filter {
        filterDesc = "internal n",
        filterSearch = "M(?=[dDtTn])",
        filterReplace = (const "n")
    },
    Filter {
        filterDesc = "internal ṇ",
        filterSearch = "M(?=[wWqQR])",
        filterReplace = (const "R")
    },
    Filter {
        filterDesc = "internal ñ",
        filterSearch = "M(?=[cCjJ])",
        filterReplace = (const "Y")
    },
    Filter {
        filterDesc = "internal ṅ",
        filterSearch = "M(?=[kKgG])",
        filterReplace = (const "N")
    },
    -}
    Filter {
        filterDesc = "final anusvāra variants", -- A 8.4.59
        --filterSearch = "M?[mN](?!\\S)|(?<=k[aiu])n(?=\\s+t)|(?<=[aiu])Y(?=\\s+[jc])",
        filterSearch = "M?[mN](?!\\S)|n(?=\\s+[tdn])|Y(?=\\s+[jc])",
        filterReplace = (const "M")
    }, 
    Filter {
        filterDesc = "visarga aḥ before voiced consonants",
        filterSearch = "(?<!\\sB)(?:a[Hr]|[o])(?=\\s+['gGjJqQdDnbBmrylvh])", -- ignore bho
        filterReplace = (const "aH")
    },
    Filter {
        filterDesc = "visarga aḥ before vowels",
        filterSearch = "aH(?=\\s+[AiIeuUof])",
        filterReplace = (const "a")
    },
    Filter {
        filterDesc = "visarga aḥ before unvoiced consonants and space + anusvāra",
        filterSearch = "o\\s+(?=[kKcCwWtTpPszSM])",
        filterReplace = (const "aH a")
    },
    Filter {
        filterDesc = "visarga āḥ variants",
        filterSearch = "AH(?=\\s+[aAiIeEuUogGjJqQdDbBnmyrlvh])",
        filterReplace = (const "A")
    },
    Filter {
        filterDesc = "other visarga variants",
        filterSearch = "H?[rszS](?!\\S)",
        filterReplace = (const "H")
    },
    Filter {
        filterDesc = "avagrahas",
        filterSearch = "'",
        filterReplace = (const "a")
    },
    {-
    Filter {
        filterDesc = "catch remaining visargas",
        --filterSearch = "H?[rszS]?(?!\\S)",
        filterSearch = "H(?!\\S)",
        filterReplace = (const "s")
    },
    -}
    Filter {
        filterDesc = "internal visarga variants",
        --filterSearch = "(?<=u)z|z(?=k)|s(?=s)",
        filterSearch = "z(?=[kK])|s(?=s)",
        filterReplace = (const "H")
    },
    Filter {
        filterDesc = "final au/āv",
        filterSearch = "Av(?!\\S)",
        filterReplace = (const "O")
    },
    Filter {
        filterDesc = "final su",
        filterSearch = "(?<=[sz])v(?=\\s+[aAiIuUoOeE])",
        filterReplace = (const "u")
    },
    Filter {
        filterDesc = "final i",
        filterSearch = "i(?=\\s+[aAuUoOeE])",
        filterReplace = (const "y")
    },
    Filter {
        filterDesc = "kcch/kś",
        filterSearch = "k(\\s*)(?:S|c?C)",
        filterReplace = (\mt -> 'k':(fst $ mt ! 1) ++ "S")
        --filterReplace = (const "kS")
    },
    {-
    Filter {
        filterDesc = "cch/ch/cś/tś",
        filterSearch = "c\\s*[CS]|t\\s+S",
        filterReplace = (const "C")
    },
    -}
    {-
    Filter {
        filterDesc = "c ch/t ś",
        filterSearch = "c\\s+C",
        filterReplace = (const "t ś")
    },

    Filter {
        filterDesc = "cś/tś",
        filterSearch = "c(\\s*)S",
        filterReplace = (\mt -> 't':(fst $ mt ! 1) ++ "S")
    },
    -}
    Filter {
        filterDesc = "cś/tś",
        filterSearch = "[tc](\\s*)S",
        filterReplace = (\mt -> 'c':(fst $ mt ! 1) ++ "C")
    },
    Filter {
        filterDesc = "cch/ch",
        filterSearch = "(?<=[aAiIuUeEoO])C",
        filterReplace = (const "cC")
    },
    Filter {
        filterDesc = "final t + hi", -- just catch most common case here
        filterSearch = "d(\\s+)D(?=[iy](?:\\s|$))",
        filterReplace = (\mt -> 't':(fst $ mt ! 1) ++ "h")
    },
    Filter {
        filterDesc = "final t + voiced syllable", -- different rule for t + h = ddh
        filterSearch = "d(?=(?:\\s+[aAiIeEuUoOgGdDbByrv]|\\s*$))",
        filterReplace = (const "t")
    },
    Filter {
        filterDesc = "final t + n/m",
        --filterSearch = "t(?=\\s[nm])",
        filterSearch = "(?<=[ai])n(?=\\s+[nm])",
        filterReplace = (const "t")
    },
    Filter {
        filterDesc = "final t + c/j",
        filterSearch = "j(?=\\s+j)|c(?=\\s+c)",
        filterReplace = (const "t")
    },
    Filter {    
        filterDesc = "i/y + vowel",
        filterSearch = "y(?=\\s+[aAuUeEoO])",
        filterReplace = (const "i")
    },
    Filter {
        filterDesc = "bhd for bdh",
        filterSearch = "Bd",
        filterReplace = (const "bD")
    }
    ]

spaceFilter' = 
    Filter {
        filterDesc = "collapse spaces",
        filterSearch = "\\s+",
        filterReplace = (const " ")
    }

spaceFilter =
    Filter {
        filterDesc = "remove spaces",
        filterSearch = "\\s+",
        filterReplace = (const "")
    }


-----
--
-- these functions are String -> String
--
-----

replaceAll :: String -> ReplaceFn -> String -> String
replaceAll re f s = start end
    where 
    (_, end, start) = foldl' go (0, s, id) ((s =~ re) :: [MatchText String])
    go (ind,read,write) mt =
        let (off,len) = snd $ mt ! 0 -- MatchText is Array [(String,(Int,Int))]; 0 is full match, followed by submatches
            (skip, start) = splitAt (off - ind) read 
            (_, remaining) = splitAt len start 
        in (off + len, remaining, write . (skip++) . (f mt ++))

filterAll :: [Filter] -> String -> String
filterAll [] s = s
filterAll (x:xs) s = filterAll xs (replaceAll (filterSearch x) (filterReplace x) s)

unfilterAll :: [Filtered] -> String -> String
unfilterAll [] s = s
unfilterAll (x:xs) s = unfilterAll xs (unreplaceAll x s)

unreplaceAll :: Filtered -> String -> String
unreplaceAll (_,[]) s = s -- when there were no replacements made
unreplaceAll (f,ms) s = start end
    where
    (_, end, start) = foldl' go (0, s, id) ms
    go (ind,read,write) m =
        let (txt,(off,origlen)) = m ! 0 -- MatchText is Array [(String,(Int,Int))]; 0 is full match, followed by submatches
            len = length $ f m
            (skip, start) = splitAt (off - ind) read 
            (_, remaining) = splitAt len start 
        in  (off + origlen, remaining, write . (skip++) . (txt++))

-------
--
-- these functions are String -> [String]
--
-------

-- outputs a list of (siglum,(unnormalized,normalized))
prepSeqs    :: [FastaSequence] -> [(String,([String],[String]))]
prepSeqs    = prepX (filters ++ [spaceFilter]) (splitGlyphs slp1')
--prepSeqs    = prepX (filters ++ [spaceFilter']) (splitGlyphs_ slp1')

prepAksaras :: [FastaSequence] -> [(String,([String],[String]))]
prepAksaras = prepX (filters ++ [spaceFilter]) (splitAksaras slp1')

prepWords   :: [FastaSequence] -> [(String,([String],[String]))]
prepWords   = prepX (filters ++ [spaceFilter']) 
                    (S.split (S.condense . S.keepDelimsR $ S.oneOf " "))

prepX :: [Filter] -> (String -> [String]) -> [FastaSequence] -> [(String,([String],[String]))]
prepX fs splitfn ss = zip sigla unfiltered
    where 
    sigla = map fastaHeader ss
    filtered :: [([Filtered],String)]
    filtered = map (filterAll' fs . unicodeToXmlEntity . transliterateString iast2slp1' . fastaSeq) ss
    unfiltered :: [([String],[String])]
    unfiltered = map go filtered
        where go (fs',s) = let split = splitfn s in (unfilterAll' fs' split,split)

replaceAll' :: String -> ReplaceFn -> String -> (Filtered,String)
replaceAll' re f s = ((f,ms),start end)
    where
    ms = ((s =~ re) :: [MatchText String])
    (_, end, start) = foldl' go (0, s, id) ms
    go (ind,read,write) m =
        let (off,len) = snd $ m ! 0 -- MatchText is Array [(String,(Int,Int))]; 0 is full match, followed by submatches
            (skip, start) = splitAt (off - ind) read 
            (_, remaining) = splitAt len start 
        in (off + len, remaining, write . (skip++) . (f m ++))

unreplaceAll' :: Filtered -> [String] -> [String]
unreplaceAll' (_,[]) ss = ss -- when there were no replacements made
unreplaceAll' (f,ms) ss = start end
    where
    (_, end, start) = foldl' go (0, ss, id) ms
    go (ind,read,write) m =
        let (txt,(off,_)) = m ! 0 -- MatchText is Array [(String,(Int,Int))]; 0 is full match, followed by submatches
            replacelen = length $ f m
            (skip,start,remlen) = splitAt' (off - ind) replacelen read
            remaining = replaceAt' (remlen,replacelen) txt start
        in  (off-remlen, remaining, write . (skip++)) -- start next search at beginning of last replacement rather than the end
        where
        splitAt' :: Int -> Int -> [String] -> ([String],[String],Int)
        splitAt' n replacelen xs = go n (id,xs) 
            where
            go :: Int -> (([String]->[String]),[String]) -> ([String],[String],Int)
            --go 0 (h,t) = (h [],t,0)
            --go n (h,[]) = (h [],[],n)
            go n (h,[x]) = (h [],[x],n)
            go n (h,xxs@(x:xs))
                | n > cell_len     = go (n - cell_len) (h . ([x]++),xs)
                | n == cell_len    = case replacelen of 0          -> (h [],xxs,n) -- stick daṇḍas, etc. at the end of a cell
                                                        replacelen -> (h [x],xs,0)
                | otherwise    = (h [],xxs,n)
                where cell_len = length x
        ---
        replaceAt' :: (Int,Int) -> String -> [String] -> [String]
        replaceAt' (n,m) y [x] =
            let (start,middle) = splitAt n x
                (_,end) = splitAt m middle
            in  [start ++ y ++ end]
        replaceAt' (n,m) y (x:xs) -- (start,length) replacement (list of strings)
            | m <= leftoverlen = 
                let (start,middle) = splitAt n x
                    (_,end) = splitAt m middle
                in  (start ++ y ++ end):xs
            | otherwise              =
                let (start,_) = splitAt n x
                    (replacewith,leftover) = splitAt leftoverlen y
                    new_m = m - leftoverlen
                in  (start ++ replacewith):(replaceAt' (0,new_m) leftover xs)
            where leftoverlen = (length x) - n

filterAll' :: [Filter] -> String -> ([Filtered],String)
filterAll' fs s = go fs [] s 
        where
        go :: [Filter] -> [Filtered] -> String -> ([Filtered],String)
        go [] us s = (us,s)
        go (x:xs) us s = go xs (u:us) result
            where 
            (u,result) = replaceAll' (filterSearch x) (filterReplace x) s

unfilterAll' :: [Filtered] -> [String] -> [String]
unfilterAll' [] ss = ss
unfilterAll' (x:xs) ss = unfilterAll' xs (unreplaceAll' x ss)
