defmodule MersenneTwister do

  use Bitwise

  defmodule MT do
    defstruct [
      f: 1812433253,
      w: 32,
      n: 624,
      m: 397,
      r: 31,
      a: 0x9908B0DF,
      u: 11,
      d: 0xFFFFFFFF,
      s: 7,
      b: 0x9D2C5680,
      t: 15,
      c: 0xEFC60000,
      l: 18
    ]
  end
  
  def init() do
    init(:os.system_time(:millisecond))
  end
  
  def init(seed) do
    init(seed,%MT{})
  end

  def init(seed,mt) when is_float(seed) do
    init(round(seed*(1 <<< mt.w)),mt)
  end

  def init(seed,mt) when is_bitstring(seed) do
    raise ArgumentError, message: "Invalid seed type: String"
  end

  def init(seed,mt) when is_integer(seed) do
    list = Stream.transform(
      1..mt.n,
      seed, 
      fn i, imin1 -> {[imin1] , lowest_n_bits(mt.w,(mt.f * (imin1 ^^^ (imin1 >>> (mt.w - 2))) + i)) } end
    ) 
    |> Enum.to_list()

    Stream.unfold({mt.n,list}, fn
      {index,arr} when index == length(arr) -> {0,twist(arr,mt)} |> (fn {acci,acca} -> {shout(Enum.fetch!(acca,acci),mt),{acci+1,acca}} end).()
      {index,arr} -> {shout(Enum.fetch!(arr,index),mt),{index+1,arr}}
      end)
  end
  
  def nextUniform(stream) do
    [x] = stream |> Stream.take(1) |> Enum.to_list()
    {x,Stream.drop(stream,1)}
  end
  
  def nextNormal(stream) do
    [u1,u2] = stream |> Stream.take(2) |> Enum.to_list()
    {box_muller(u1,u2),Stream.drop(stream,2)}
  end

  def box_muller(u1,u2) do
    :math.sqrt(-2*:math.log(u1))*:math.cos(2*:math.pi()*u2)
  end
  
  defp lowest_n_bits(n,x) do
    x &&& ((1<<<n)-1)
  end

  defp twist(arr,mt) do
    Enum.map(0..mt.n-1,fn i -> ((Enum.fetch!(arr,i) &&& upper_mask(mt) ) + (Enum.fetch!(arr,rem(i+1,mt.n)) &&& lower_mask(mt))) |>
      (fn x -> x >>> 1 end).() |>
      (fn xA -> case rem(xA,2) do
        0 -> xA
        1 -> xA ^^^ mt.a
      end
      end).() |>
        (fn xA -> Enum.fetch!(arr,rem(i + mt.m,mt.n)) ^^^ xA end).()
    end)
  end

  defp shout(val,mt) do
    val |>
    (fn y -> y ^^^ ((y >>> mt.u) &&& mt.d) end).() |>
    (fn y -> y ^^^ ((y <<< mt.s) &&& mt.b) end).() |>
    (fn y -> y ^^^ ((y <<< mt.t) &&& mt.c) end).() |>
    (fn y -> y ^^^ (y >>> 1) end).() |>
    (fn y -> lowest_n_bits(mt.w,y) end).() |>
    (fn y -> y/(1 <<< mt.w) end).()
  end

  defp lower_mask mt do
    (1 <<< mt.r) - 1
  end

  defp upper_mask mt do
    lowest_n_bits(mt.w,bnot(lower_mask(mt)))
  end
  
end


