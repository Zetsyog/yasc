%{
#include <stdio.h>
#include <stdlib.h>
#include "generation/defs.h"
#include "grammar.h"
#include "util.h"
#include "generation/print_code.h"

int yylex();
int yyparse();
void yyerror(const char *s);
%}

%define parse.error verbose

%union {
        struct {
                struct list_t *true;
                struct list_t *false;
        } cond;
        struct list_t *pos;
        struct {
                void *ptr;
        } var;
        struct node_t *list;
        int quad;
        int intVal;
        char strVal[SYM_NAME_MAX_LEN];
        struct symbol_t *sym;
        unsigned int a_type;
}

%token PROG VAR UNIT BOOL ARRAY FUNC REF IF THEN ELSE
%token WHILE RETURN BEGIN_TOK READ WRITE COM
%token END AND OR XOR NOT DO OF
%token <intVal> INT
%token <strVal> IDENT

%left XOR OR '+' '-'
%left AND '*' '/'
%left '^'
%left OPU NOT

%type <var> expr
%type <sym> lvalue
%type <a_type> varsdecl atomictype typename
%type <list> vardeclist identlist

%nonassoc IFEND
%nonassoc ELSE

%start program

%%
program: PROG IDENT vardeclist fundecllist instr
       ;

vardeclist: /*epsilon*/ { $$ = NULL; }
          | varsdecl {  }
          | varsdecl ';' vardeclist {}
          ;

varsdecl: VAR identlist ':' typename { 
    if($4 == A_UNIT)
        log_error("syntax error: var cannot be of type UNIT");
    
    struct node_t *list = $2;
    struct symbol_t *tmp = (struct symbol_t *)list->data;
    while(tmp != NULL) {
        tmp->atomic_type = $4;
        tmp->sym_type = SYM_VAR;

        st_put(tmp->name, tmp);

        list = list->next;
        if(list == NULL)
            break;
        tmp = (struct symbol_t *) list->data;
    }
}
        ;

identlist: IDENT    {
                log_debug("creating new identlist with %s", $1);
                struct symbol_t *sym = sym_create($1, 0, 0);
                log_debug("sym name: %s", sym->name);
                $$ = node_create(sym);
                sym = (struct symbol_t *) $$->data;
                log_debug("sym name2: %s", sym->name);

            }
         | identlist ',' IDENT  {
                log_debug("append %s to identlist", $3);
                node_append($1, sym_create($3, 0, 0));
                $$ = $1;
            }
         ;

typename: atomictype { $$ = $1; }
        | arraytype { }
        ;

atomictype: UNIT { $$ = A_UNIT; }
          | BOOL { $$ = A_BOOL; }
          | INT  { $$ = A_INT; }
          ;

arraytype: ARRAY '[' rangelist ']' OF atomictype
         ;

rangelist: INT '.' '.' INT
         | INT '.''.' INT ',' rangelist
         ;

fundecllist: /*epsilon*/              { }
           | fundecl ';' fundecllist { }
           ;

fundecl: FUNC IDENT '(' parlist ')' ':' atomictype vardeclist instr
       ;

parlist: /*epsilon*/     { }
       | par             { }
       | par ',' parlist { }
       ;

par: IDENT ':' typename
   | REF IDENT ':' typename
   ;

instr: IF expr THEN M instr { }
     | IF expr THEN M instr ELSE N instr { }
     | WHILE expr DO M instr {  }
     | lvalue ':' '=' expr { gencode(ASSIGNMENT, $4.ptr, $1); }
     | RETURN expr
     | RETURN
     | IDENT '(' exprlist ')'
     | IDENT '(' ')'
     | BEGIN_TOK sequence END { }
     | BEGIN_TOK END
     | READ lvalue { }
     | WRITE expr { }
     ;

sequence: instr ';' M sequence { }
        | instr ';'            { }
        | instr                { }
        ;

M: /* empty */  { }
 ;

N:  { }
 ;


lvalue: IDENT { 
            struct st_entry_t *e = st_get($1);
            if(e == NULL) {
                log_error("syntax error: ident %s not declared", $1);
                exit(1);
            }
            $$ = e->value;
        }
      | IDENT '[' exprlist ']'  {}
      ;

exprlist: expr
        | expr ',' exprlist
        ;

expr: INT { 
    $$.ptr = newtemp(SYM_CST, A_INT, $1);
}
    | '(' expr ')'            { }
    | expr opb expr
    | opu expr
    | IDENT '('exprlist ')'
    | IDENT '(' ')'
    | IDENT '[' exprlist ']'
    | IDENT
    ;

opb:'+'    { }
   |'-'    { }
   |'*'    { }
   |'/'    { }
   |'<'    { }
   |'<''=' { }
   |'>'    { }
   |'>''=' { }
   |'='    { }
   |'<''>' { }
   | AND   { }
   | OR    { }
   | XOR   { }
   ;

opu: '-' %prec OPU{ }
   | NOT { }
   ;

%%

int main(void)
{
    log_info("Starting compilation");
    st_create(10000);
    nextquad = 0;
    yyparse();
    log_info("done");
    log_debug("Sym table :");

    log_debug("Result :");
    print_intermediate_code();
    st_destroy();
    return 0;
}

void yyerror(const char *s)
{
    fprintf(stderr,"%s\n",s);
}
