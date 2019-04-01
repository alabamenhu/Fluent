-dog =
  { $style ->
     *[normal          ] dog
      [diminutive      ] puppy
      [diminutive-redup] puppy dog
  }

-cat =
  { $style ->
     *[normal          ] cat
      [diminutive      ] kitten
      [diminutive-redup] kitty cat
  }

cute       = Wow, that { -$animal(style: "diminutive") } is so cute!
stupidcute = OMG, that { -$animal(style: "diminutive-redup") } is like so amazeballs cute!
handsome   = That's a handsome { -$animal(style: "normal") } is so cute!
