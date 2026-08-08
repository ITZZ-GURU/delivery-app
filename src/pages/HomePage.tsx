<div className="grid grid-cols-1 md:grid-cols-2 gap-12 items-center">

  {/* LEFT — Our Story */}
  <div>
    ...
  </div>

  {/* RIGHT — Image Grid */}
  <div className="grid grid-cols-2 gap-4">

    <img ... />

    <img ... />

    <div className="relative -mt-4">
      <img
        src="https://images.pexels.com/photos/12392915/pexels-photo-12392915.jpeg?auto=compress&cs=tinysrgb&h=650&w=940"
        alt="Masala dosa"
        className="rounded-xl shadow-lg h-64 w-full object-cover"
      />
    </div>

    <img ... />

  </div>

  {/* CENTERED TO THE WHOLE PAGE */}
  <div className="md:col-span-2 justify-self-center -mt-6 flex items-center gap-2 rounded-xl bg-gold-400 px-5 py-3 shadow-xl z-10 whitespace-nowrap">
    <ChefHat className="h-6 w-6 text-charcoal-900" />
    <span className="font-serif font-bold text-charcoal-900">
      Home-style cooking
    </span>
  </div>

</div>
