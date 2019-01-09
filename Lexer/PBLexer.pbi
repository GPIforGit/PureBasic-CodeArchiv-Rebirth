﻿;   Description: Lexer for PureBasic codes
;            OS: Windows, Linux, Mac
; English-Forum: 
;  French-Forum: 
;  German-Forum: 
; -----------------------------------------------------------------------------

; MIT License
; 
; Copyright (c) 2019 Sicro
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

; ==========================================================================================================================
;- Inclusions of code files
; ==========================================================================================================================
IncludeFile "Lexer.pbi"

; ==========================================================================================================================
;- Declaration of module 'PBLexer'
; ==========================================================================================================================
DeclareModule PBLexer
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Compiler settings
  ; ------------------------------------------------------------------------------------------------------------------------
  EnableExplicit
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Declaration of procedures
  ; ------------------------------------------------------------------------------------------------------------------------
  Declare  Create(string$, maxTokenValueLength=200)
  Declare  Free(*lexer)
  Declare  NextToken(*lexer)
  Declare$ TokenName(*lexer)
  Declare  TokenType(*lexer)
  Declare$ TokenValue(*lexer)
  Declare  TokenValueLength(*lexer)
  Declare  StringOffset(*lexer, value=-1)
  Declare  StringLineNumber(*lexer)
  Declare  StringColumnNumber(*lexer)
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Definition of constants
  ; ------------------------------------------------------------------------------------------------------------------------
  Enumeration 1 ; Must start at "1", because of the internal constant "#TokenType_Whitespace", which has "0"
    #TokenType_Newline
    #TokenType_Identifier
    #TokenType_Separator
    #TokenType_Operator
    #TokenType_Keyword
    #TokenType_Comment
    #TokenType_Number
    #TokenType_String
    #TokenType_Constant
    #TokenType_Period
    #TokenType_DoubleColon ; ModuleName::ObjectName
    #TokenType_PassThroughASM
  EndEnumeration
EndDeclareModule

Module PBLexer
  #TokenType_Whitespace = 0
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Definition of procedures
  ; ------------------------------------------------------------------------------------------------------------------------
  Procedure Create(string$, maxTokenValueLength=200)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Creates a new lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    |             string$ -- The string to be scanned
    ;               | maxTokenValueLength -- Specifies the length of the substring in which a token is to be scanned.
    ;               |                        Too large values slow down the Lexer.
    ;               |                        Too low values can cause the substring to be too short and some tokens can no
    ;               |                        longer be read out completely. It is also possible that some tokens are not
    ;               |                        recognized at all, because the RegEx of the token no longer matches
    ;               |                        (Optional - default is 300)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | On success the handle of the created lexer, otherwise #False
    ; ----------------------------------------------------------------------------------------------------------------------
    Protected *lexer
    Protected regEx$
    *lexer = Lexer::Create(string$, maxTokenValueLength)
    If *lexer
      
      ; --------------------------------------------------------------------------------------------------------------------
      ;- > Definition of all token types
      ; --------------------------------------------------------------------------------------------------------------------
      Lexer::DefineNewToken(*lexer, #TokenType_Whitespace, "[ \t]+", #True)
      
      Lexer::DefineNewToken(*lexer, #TokenType_Newline, "[\r\n]", #False, "NewLine")
      
      Lexer::DefineNewToken(*lexer, #TokenType_DoubleColon, "::", #False, "DoubleColon")
      
      Lexer::DefineNewToken(*lexer, #TokenType_Separator, "[()\[\]{}\\:,]", #False, "Separator")
      
      ; The token directly below this comment must be defined before the identifier token!
      ; Otherwise, this token type is never recognized, because the identifier token will consume it
      Lexer::DefineNewToken(*lexer, #TokenType_Keyword, PeekS(?PBKeywords), #False, "Keyword")
      
      Lexer::DefineNewToken(*lexer, #TokenType_Identifier, "(?:[A-Z_]+[A-Z0-9_]*)\b\$?", #False, "Identifier")
      
      Lexer::DefineNewToken(*lexer, #TokenType_Comment, ";[^\r^\n]*", #False, "Comment")
      
      Lexer::DefineNewToken(*lexer, #TokenType_String, ~"~\"(?:\\\\.|.)*?\"|\".*?\"", #False, "String")
      
      regEx$ = "[0-9]+(?:\.[0-9]+)?(?:e[0-9]+)?" + ; Integers and decimal numbers
               "|" +
               "%[01]+" + ; Binary numbers
               "|" +
               "\$[0-9A-F]+" + ; Hexadecimal numbers
               "|" +
               "'.*?'" ; 'a'
      Lexer::DefineNewToken(*lexer, #TokenType_Number, regEx$, #False, "Number")
      
      ; The token directly below this comment must be defined after the string token!
      ; Otherwise, this token type will consume the character "~" as an operator
      Lexer::DefineNewToken(*lexer, #TokenType_Operator, "and|or|xor|not|<<|>>|<=|>=|=<|=>|[|+\-*/!%&<>=@?~]", #False,
                            "Operator")
      
      Lexer::DefineNewToken(*lexer, #TokenType_Constant, "(?:#[A-Z_]+[A-Z0-9_]*)\b\$?", #False, "Constant")
      
      Lexer::DefineNewToken(*lexer, #TokenType_Period, "\.", #False, "Period")
    EndIf
    ProcedureReturn *lexer
  EndProcedure
  
  Procedure Free(*lexer)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Frees the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer to be freed
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | None
    ; ----------------------------------------------------------------------------------------------------------------------
    Lexer::Free(*lexer)
  EndProcedure
  
  Procedure NextToken(*lexer.Lexer::LexerStruc)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Determines the next token
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | #True, if a token was found, otherwise #False
    ; ----------------------------------------------------------------------------------------------------------------------
    Static lastTokenType = #TokenType_Newline ; This has the effect that ASM code is also recognized in the first line of
                                              ; code
    Protected asmCode$, character$
    Protected stringOffset
    While Lexer::NextToken(*lexer)
      Select Lexer::TokenType(*lexer)
        Case Lexer::#TokenType_Unkown
          
          ; ----------------------------------------------------------------------------------------------------------------
          ;- > Process the unkown token type
          ; ----------------------------------------------------------------------------------------------------------------
          ProcedureReturn #True
        Case #TokenType_NewLine
          
          ; ----------------------------------------------------------------------------------------------------------------
          ;- > Process ASM code that is passed directly to the assembler
          ; ----------------------------------------------------------------------------------------------------------------
          *lexer\currentTokenValue$ = "" ; For the new line token, no token value should be displayed
          ProcedureReturn #True
        Default
          If lastTokenType = #TokenType_Newline And Lexer::TokenType(*lexer) = #TokenType_Operator And
             Lexer::TokenValue(*lexer) = "!"
            
            ; --------------------------------------------------------------------------------------------------------------
            ;- > Process ASM code that is passed directly to the assembler
            ; --------------------------------------------------------------------------------------------------------------
            ; An exclamation mark directly at the beginning of a line indicates that ASM code now follows until the end of
            ; the line is reached
            asmCode$ = "!"
            stringOffset = Lexer::StringOffset(*lexer) ; Get current string position from lexer
            Repeat
              ; Combine all following characters until one of these characters is recognized: #CR$, #LF$ or ";"
              character$ = Mid(*lexer\string$, stringOffset, 1)
              Select character$
                Case #CR$, #LF$, ";"
                  Break
                Default
                  asmCode$ + character$
              EndSelect
              stringOffset + 1
            Until character$ = ""
            Lexer::StringOffset(*lexer, stringOffset) ; Set the new string position to the lexer
            *lexer\currentTokenType        = #TokenType_PassThroughASM
            *lexer\currentTokenName$       = "PassThroughASM"
            *lexer\currentTokenValue$      = asmCode$
            *lexer\currentTokenValueLength = Len(asmCode$)
            ProcedureReturn #True
          Else
            
            ; --------------------------------------------------------------------------------------------------------------
            ;- > Process all other token types
            ; --------------------------------------------------------------------------------------------------------------
            ProcedureReturn #True
          EndIf
      EndSelect
      lastTokenType = Lexer::TokenType(*lexer)
    Wend
  EndProcedure
  
  Procedure$ TokenName(*lexer.Lexer::LexerStruc)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the name of the current token
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | Token name
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn *lexer\currentTokenName$
  EndProcedure
  
  Procedure TokenType(*lexer.Lexer::LexerStruc)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the type of the current token
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | Token type. On error: -1
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn *lexer\currentTokenType
  EndProcedure
  
  Procedure$ TokenValue(*lexer.Lexer::LexerStruc)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the value of the current token
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | Token value
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn *lexer\currentTokenValue$
  EndProcedure
  
  Procedure TokenValueLength(*lexer.Lexer::LexerStruc)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the value length of the current token
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | Token value length. On error: -1
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn *lexer\currentTokenValueLength
  EndProcedure
  
  Procedure StringOffset(*lexer.Lexer::LexerStruc, value=-1)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns or sets the current string offset from the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ;               | value  -- The new string offset
    ;               |           (Optional - default is -1 (set nothing))
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | String offset. On error: -1
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn Lexer::StringOffset(*lexer, value)
  EndProcedure
  
  Procedure StringLineNumber(*lexer)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the current string line number from the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | String line number. On error: -1
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn Lexer::StringLineNumber(*lexer)
  EndProcedure
  
  Procedure StringColumnNumber(*lexer)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the current column number from the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | *lexer -- The handle of the lexer
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | String column number. On error: -1
    ; ----------------------------------------------------------------------------------------------------------------------
    ProcedureReturn Lexer::StringColumnNumber(*lexer)
  EndProcedure
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Data section
  ; ------------------------------------------------------------------------------------------------------------------------
  DataSection
    PBKeywords:
    Data$ "(?:align|array|as|break|calldebugger|case|compilercase|compilerdefault|compilerelse|compilerelseif|" +
          "compilerendif|compilerendselect|compilererror|compilerif|compilerselect|compilerwarning|continue|data|" +
          "datasection|debug|debuglevel|declare|declarec|declarecdll|declaredll|declaremodule|default|define|dim|" +
          "disableasm|disabledebugger|disableexplicit|else|elseif|enableasm|enabledebugger|enableexplicit|end|" +
          "enddatasection|enddeclaremodule|endenumeration|endif|endimport|endinterface|endmacro|endmodule|endprocedure|" +
          "endselect|endstructure|endstructureunion|endwith|enumeration|enumerationbinary|extends|fakereturn|for|foreach|" +
          "forever|global|gosub|goto|if|import|importc|includebinary|includefile|includepath|interface|list|macro|map|" +
          "module|newlist|newmap|next|procedure|procedurec|procedurecdll|proceduredll|procedurereturn|protected|" +
          "prototype|prototypec|read|redim|repeat|restore|return|runtime|select|shared|static|step|structure|" +
          "structureunion|swap|threaded|to|until|unusemodule|usemodule|wend|while|with|xincludefile)\b\$?"
    Data.c 0
  EndDataSection
EndModule

; ==========================================================================================================================
;- Example code
; ==========================================================================================================================
CompilerIf #PB_Compiler_IsMainFile
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Definition of procedures
  ; ------------------------------------------------------------------------------------------------------------------------
  Procedure$ GetContentOfFile(fileName$)
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Description:  | Returns the complete content of the file
    ;               | Supported BOMs: Ascii, UTF8, Unicode
    ;               | In case of a unsupported BOM the file will be readed as UTF8
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Parameter:    | fileName$
    ; ----------------------------------------------------------------------------------------------------------------------
    ; Return value: | File content
    ; ----------------------------------------------------------------------------------------------------------------------
    Protected file, stringFormat
    Protected content$
    file = ReadFile(#PB_Any, fileName$)
    If file
      stringFormat = ReadStringFormat(file)
      Select stringFormat
        Case #PB_Ascii, #PB_UTF8, #PB_Unicode
        Default
          ; ReadString() supports fewer string formats than ReadStringFormat(), so in case of an
          ; unsupported format it is necessary to fall back to a supported format
          stringFormat = #PB_UTF8
      EndSelect
      content$ = ReadString(file, stringFormat|#PB_File_IgnoreEOL)
      CloseFile(file)
    EndIf
    ProcedureReturn content$
  EndProcedure
  
  Procedure UnusedProcedure()
    ; This procedure serves as a dummy for an unused procedure
  EndProcedure
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Definition of local variables
  ; ------------------------------------------------------------------------------------------------------------------------
  Define fileName$ = #PB_Compiler_File ; For the example, the PBLexer code file itself is used
  Define code$, keywordName$
  Define *pbLexer
  Define stringOffset
  Define NewMap countOfCallsOfDefinedProceduresMap()
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Read code file
  ; ------------------------------------------------------------------------------------------------------------------------
  code$ = GetContentOfFile(fileName$)
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Create lexer
  ; ------------------------------------------------------------------------------------------------------------------------
  *pbLexer = PBLexer::Create(code$)
  If *pbLexer = 0
    Debug "PBLexer can't be created!"
    End
  EndIf
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Search all procedure definitions and count the calls of these procedures
  ; ------------------------------------------------------------------------------------------------------------------------
  ; Note: This code does not handle procedures of different modules separately
  While PBLexer::NextToken(*pbLexer)
    Select PBLexer::TokenType(*pbLexer)
      Case PBLexer::#TokenType_Keyword
        keywordName$ = LCase(PBLexer::TokenValue(*pbLexer))
        Select keywordName$
          Case "procedure", "procedure$" ; Start keyword of a procedure definition block
            Debug "A procedure definition was found:"
            If PBLexer::NextToken(*pbLexer)
              If Right(keywordName$, 1) = "$" ; Support for "Procedure$"
                Debug "Procedure return type: s"
              ElseIf PBLexer::TokenType(*pbLexer) = PBLexer::#TokenType_Period And PBLexer::NextToken(*pbLexer) And
                     PBLexer::TokenType(*pbLexer) = PBLexer::#TokenType_Identifier
                ; The procedure has a return type definition
                Debug "Procedure return type: " + PBLexer::TokenValue(*pbLexer)
                PBLexer::NextToken(*pbLexer)
              Else ; No procedure return type was defined
                Debug "Procedure return type: i" ; Default procedure return type is "i" (Integer)
              EndIf
              If PBLexer::TokenType(*pbLexer) = PBLexer::#TokenType_Identifier
                Debug "Procedure name: " + PBLexer::TokenValue(*pbLexer)
                AddMapElement(countOfCallsOfDefinedProceduresMap(), PBLexer::TokenValue(*pbLexer))
              EndIf
            EndIf
            Debug "-----------------------------------------------------"
        EndSelect
      Case PBLexer::#TokenType_Identifier
        If FindMapElement(countOfCallsOfDefinedProceduresMap(), PBLexer::TokenValue(*pbLexer))
          ; An identifier was found that has the same name as one of the defined procedures.
          ; However, it can also be a variable, so it must also be checked whether the identifier is followed by an opening
          ; bracket.
          stringOffset = PBLexer::StringOffset(*pbLexer)
          If PBLexer::NextToken(*pbLexer) And PBLexer::TokenType(*pbLexer) = PBLexer::#TokenType_Separator And
             PBLexer::TokenValue(*pbLexer) = "("
            countOfCallsOfDefinedProceduresMap() + 1
          EndIf
          PBLexer::StringOffset(*pbLexer, stringOffset)
        EndIf
    EndSelect
  Wend
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > List all defined procedures and the count of their calls
  ; ------------------------------------------------------------------------------------------------------------------------
  Debug "====================================================="
  Debug "All defined procedures and the count of their calls:"
  Debug "====================================================="
  ForEach countOfCallsOfDefinedProceduresMap()
    Debug MapKey(countOfCallsOfDefinedProceduresMap()) + ": " + Str(countOfCallsOfDefinedProceduresMap())
  Next
  
  ; ------------------------------------------------------------------------------------------------------------------------
  ;- > Free lexer
  ; ------------------------------------------------------------------------------------------------------------------------
  Lexer::Free(*pbLexer)
CompilerEndIf
