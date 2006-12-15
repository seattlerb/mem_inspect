begin
  require 'inline'
rescue LoadError
  require 'rubygems'
  require 'inline'
end

##
# ObjectSpace.each_object on crack.
#
# MemInspect allows you to walk Ruby's heaps and gives you the contents of
# each heap slot.

class MemInspect

  inline do |builder|
    builder.include '"node.h"' # struct RNode
    builder.include '"st.h"'  # struct st_table
    builder.include '"re.h"'  # struct RRegexp
    builder.include '"env.h"' # various structs

    builder.prefix <<-EOC
      typedef struct RVALUE {
          union {
              struct {
                  unsigned long flags; /* always 0 for freed obj */
                  struct RVALUE *next;
              } free;
              struct RBasic  basic;
              struct RObject object;
              struct RClass  klass;
              struct RFloat  flonum;
              struct RString string;
              struct RArray  array;
              struct RRegexp regexp;
              struct RHash   hash;
              struct RData   data;
              struct RStruct rstruct;
              struct RBignum bignum;
              struct RFile   file;
              struct RNode   node;
              struct RMatch  match;
              struct RVarmap varmap;
              struct SCOPE   scope;
          } as;
      } RVALUE;

      struct heaps_slot {
          void *membase;
          RVALUE *slot;
          int limit;
      };

      struct heaps_slot * rb_gc_heap_slots();
      int rb_gc_heaps_used();
      int rb_gc_heaps_length();
    EOC

    ##
    # Number of struct heaps_slots used

    builder.c <<-EOC
      static int
      heaps_used() {
        return rb_gc_heaps_used();
      }
    EOC

    ##
    # Length of the struct heaps_slots allocated (I think)

    builder.c <<-EOC
      static int
      heaps_length() {
        return rb_gc_heaps_length();
      }
    EOC

    # [Type flag, object size, object]

    types = [
      ['T_NONE',    0, 'unknown'],
      ['T_NIL',     0, 'Qnil'],
      ['T_OBJECT',  'sizeof(struct RObject) + sizeof(struct st_table)'],
      ['T_CLASS',   'sizeof(struct RClass) + sizeof(struct st_table) * 2'],
      ['T_ICLASS',  'sizeof(struct RClass)', 'iclass'],
      ['T_MODULE',  'sizeof(struct RObject) + sizeof(struct st_table) * 2'],
      ['T_FLOAT',   'sizeof(struct RFloat)'],
      ['T_STRING',
       'sizeof(struct RString) + (FL_TEST(RSTRING(p), ELTS_SHARED) ? 0 : RSTRING(p)->len)'],
      ['T_REGEXP',  'sizeof(struct RRegexp) + RREGEXP(p)->len'],
      ['T_ARRAY',
       'sizeof(struct RArray) + (FL_TEST(RARRAY(p), ELTS_SHARED) ? 0 : RARRAY(p)->len * 4)'],
      ['T_FIXNUM',  0],
      ['T_HASH',    'sizeof(struct RHash) + sizeof(struct st_table)'],
      ['T_STRUCT',  'sizeof(struct RStruct) + RSTRUCT(p)->len'],
      ['T_BIGNUM',  'sizeof(struct RBignum) + RBIGNUM(p)->len'],
      ['T_FILE',    'sizeof(struct RFile)'],

      ['T_TRUE',    0, 'Qtrue'],
      ['T_FALSE',   0, 'Qfalse'],
      ['T_DATA',    'sizeof(struct RData)'],
      ['T_MATCH',   'sizeof(struct RMatch)'],
      ['T_SYMBOL',  0],

      ['T_BLKTAG',  0, 'unknown'],
      ['T_UNDEF',   0, 'unknown'],
      ['T_VARMAP',  'sizeof(struct RVarmap)', 'varmap'], # TODO linked-list
      ['T_SCOPE',
       'sizeof(struct SCOPE) +
        (((struct SCOPE *)p)->local_tbl ? ((struct SCOPE *)p)->local_tbl[0] : 0)',
       'scope'],
      ['T_NODE', 'sizeof(struct RNode)', 'node'], # TODO SCOPE and ALLOCA nodes
    ]

    types.each do |type|
      type[2] = '(VALUE)p' if type[2].nil?
    end

    ##
    # Generates the cases for the switch statement

    def self.make_switch(types)
      types.map do |type, size, object|
        ["case #{type}:",
         "  size = #{size};",
         "  obj = #{object};",
         "  break;",
         nil]
      end.join("\n")
    end

    ##
    # Walks the heap slots yielding each item's address, size and value.
    #
    # The value may be:
    # :__free:: Unassigned heap slot
    # Object:: Ruby object
    # :__node:: Ruby AST node
    # :__iclass:: module instance (created via include)
    # :__scope:: ruby interpreter scope
    # :__varmap:: variable map (see eval.c, parse.y)
    # :__unknown:: unknown item
    #
    # The size of objects may not be correct.  Please fix if you find an
    # error.

    builder.c <<-EOC
      static void
      walk() {
        RVALUE *p, *pend;
        VALUE ary = rb_ary_new2(3);
        VALUE unknown = ID2SYM(rb_intern("__unknown"));
        VALUE iclass = ID2SYM(rb_intern("__iclass"));
        VALUE varmap = ID2SYM(rb_intern("__varmap"));
        VALUE scope = ID2SYM(rb_intern("__scope"));
        VALUE node = ID2SYM(rb_intern("__node"));
        VALUE free = ID2SYM(rb_intern("__free"));
        VALUE obj = unknown;
        long size = 0;
        struct heaps_slot * heaps = rb_gc_heap_slots();
        int i;

        for (i = 0; i < rb_gc_heaps_used(); i++) {
          p = heaps[i].slot;
          pend = p + heaps[i].limit;
          for (; p < pend; p++) {
            size = 0;
            obj = free;
            if (p->as.basic.flags) { /* always 0 for freed objects */
              switch (TYPE(p)) {
                #{make_switch types}

                default:
                  if (!p->as.basic.klass) {
                    obj = unknown;
                  } else {
                    obj = (VALUE)p;
                  }
              }

              if (FL_TEST(obj, FL_EXIVAR))
                size += sizeof(struct st_table);
            }
            rb_ary_store(ary, 0, LONG2NUM((long)p));
            rb_ary_store(ary, 1, INT2FIX(size));
            rb_ary_store(ary, 2, obj);

            rb_yield(ary);
          }
        }
      }
    EOC
  end

end

