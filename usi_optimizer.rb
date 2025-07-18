# USI Optimizer; relevant after getting spliced crew

# Usage:
# 1. Update constants to reflect the state of your game. FOCI should hold all the areas 
#    you might want to focus your efforts on. If you want to temporarily ignore some of them, add those
#    to FOCI_TO_IGNORE. The names are limited to 5 characters for printing.
# 
#    Things about this that you might want to update: 
#    a) I don't include foci that I'm done with (e.g. overdrive, power)

# 2. CREW_ALLOCATIONS exists to limit our combinatorial explosion. I precompute the foci that crew can contribute to, then
#    do the one-time effort of finding all maximal compatible arrangements of crew. 
#
#    Things about this you might want to update:
#    a) I have eliminated some foci that are irrelevant to me, but you might want to add them back. E.g. Overdrive.
#    b) For Yttaldar and Verdanix (Yt and Vx): both of these have 2 crew that can focus on them, and having both
#       greatly improves efficiency since it's based on the total Yt or Vx, If you're open to having just one of these running,
#       then modify crew allocations accordingly. This will likely open up new allocations where the secondary producer of
#       Yt or Vx is focused on something else.

# 3. SHARDS: This stores where shards can be placed (placements), and which colors activate which areas of focus (color_to_focus)

# 4. MAX_LINKS & MAX_MODULES are self explanatory -- update these if they change.

# How it works:
# Broadly, we iterate through the crew allocations. For each of these, we iterate through shard placements and link 
# arrangements to find which sets of foci are activated (meaning they're operating at 100% efficiency. I.e., that
# all things that can contribute to them are contributing to them.
#
# We then eliminate any set of foci which is completely covered by another set of foci. E.g., if one solution can focus on
# Warp, Specimen, and resources, then we get rid of solutions that only cover one or two of these areas.
#
# Finally, if there are multiple solutions for a set of areas, I pick the one with the fewest links.

# How it could be improved:
# Probably in many ways, but the main thing I don't have implemented that would be helpful for people who haven't
# finished their reactor is including the utility cores in the optimization. I handle the fact that the Veil Piercer can only
# Help Synth/Fixture or Resources but not both with a bit of logic, but I don't handle which cores are active because
# at EoC people are done with the reactor.

MAX_LINKS = 6
MAX_MODULES = 18

# FOCI are areas we can focus our efforts on in USI
FOCI = [:B6com, :B6mat, :B6par, :Combt, :Fghtr, :Fixtr, :Mstry, :Resou, :Rsh_H, :Rsh_S, :Shard, :Spcmn, :Synth, :Warp]
FOCI_TO_IGNORE = [:Fghtr, :Shard]
FOCI_TO_PRINT = FOCI - FOCI_TO_IGNORE

# FOCI_CREW are FOCI that crew can boost
FOCI_CREW = [:Fixtr, :Rsh_H, :Rsh_S, :Spcmn, :Synth, :Warp]
FOCI_NONCREW = FOCI - FOCI_CREW
CREW = [:SR, :ST, :SP, :ME]


Crew_Allocation = Struct.new(:SR, :ST, :ME, :SP, :FOCI) do
  def initialize(sr, st, me, sp, foci)
    invalid_foci = foci.reject { |f| FOCI.include?(f) }

    unless invalid_foci.empty?
      raise ArgumentError, "Invalid crew allocation foci: #{invalid_foci.inspect}. Must be in FOCI: #{FOCI.inspect}"
    end

    super(sr, st, me, sp, foci)
  end
end


Shard = Struct.new(:name, :placements, :color_to_focus, :cur_placement, keyword_init: true) do
  def initialize(name:, placements:, color_to_focus:, cur_placement: nil)
    color_to_focus.each do |color, focus|
      raise ArgumentError, "Invalid focus `#{focus}` for color `#{color}` in shard `#{name}`. Must be one of: #{FOCI.join(', ')}" unless FOCI.include?(focus)
    end
    super
  end

  def to_s
    "#{name.to_s} #{cur_placement.to_s} #{placements.to_s} #{color_to_focus.to_s}"
  end

  def inspect
    name.to_s
  end
end


CREW_ALLOCATIONS = [ # SR   ST   ME   SP
  Crew_Allocation.new(:Di, nil, :Yt, :Yt, [:Rsh_H, :Synth, :Mstry]),
  Crew_Allocation.new(:Di, nil, :Zt, nil, [:Rsh_H, :Spcmn]),
  Crew_Allocation.new(:Vx, :Vx, :Di, nil, [:Rsh_S, :Fixtr]),
  Crew_Allocation.new(:Vx, :Vx, :Yt, :Yt, [:Rsh_S, :Synth, :Mstry]),
  Crew_Allocation.new(:Vx, :Vx, :Zt, nil, [:Rsh_S, :Spcmn]),
  Crew_Allocation.new(:Xt, nil , :Zt, :Di, [:Warp, :Spcmn]),
]


SHARDS = [
  Shard.new(name: :Produ, placements: [:Red, :Green, :Pink], color_to_focus: { Red: :B6mat, Pink: :B6par, Green: :B6com }),
  Shard.new(name: :Synth, placements: [:Red], color_to_focus: { Red: :Synth, Pink: :Fixtr }),
  Shard.new(name: :Captl, placements: [:Orange, :Green], color_to_focus: { Orange: :Combt, Green: :Combt }),
  Shard.new(name: :Flex, placements: [:Red, :Orange, :Green, :Blue, :Pink], color_to_focus: { Red: :Rsh_H, Orange: :Synth, Green: :Warp, Pink: :Shard }),
  Shard.new(name: :Fghtr, placements: [:Red, :Orange], color_to_focus: { Red: :Fghtr, Orange: :Fghtr, Green: :Resou }),
  Shard.new(name: :Rsrch, placements: [:Green, :Blue, :Pink], color_to_focus: { Green: :Rsh_S, Blue: :Rsh_H, Pink: :Rsh_S, Orange: :Rsh_S }),
  Shard.new(name: :Resou, placements: [:Red, :Orange, :Blue], color_to_focus: { Red: :Resou, Orange: :Resou, Blue: :Resou }),
  Shard.new(name: :Spcmn, placements: [:Red, :Green, :Pink], color_to_focus: { Red: :Spcmn, Orange: :Spcmn, Green: :Spcmn, Blue: :Spcmn, Pink: :Spcmn })
]


COLORS = [:Blue, :Green, :Orange, :Pink, :Red]


LINKS = []
COLORS.combination(2).each do |color_pair|
  LINKS.append(color_pair.sort!)
end


def sym_list_to_string(sym_list, width)
  str = "|"
  sym_list.each do |elt|
    text = elt.to_s[0, width]  
    str += text.center(width) + "|"
  end
  return str
end


def usi
  foci_to_solution = {}
  dominated_foci = Set.new()
  dominated_foci.add([])

  CREW_ALLOCATIONS.each do |crew_allocation|
    # Determine eligible foci & shards given the crew allocation
    eligible_foci = crew_allocation.FOCI + FOCI_NONCREW
    ineligible_foci = FOCI_CREW - eligible_foci
    ineligible_foci += FOCI_TO_IGNORE
    ineligible_foci.uniq!
    eligible_shards = []
    
    # Determine which shards are compatible with the current crew
    # I.e., remove any shards which are not compatible with any possible areas of focus given crew
    focus_to_shards = Hash.new { |h, k| h[k] = Set.new() }
    SHARDS.each do |shard|
      shard.color_to_focus.values.each do |focus|
        next if ineligible_foci.include?(focus)
        focus_to_shards[focus].add(shard)
        eligible_shards.append(shard) unless eligible_shards[-1] == shard
      end
    end
    eligible_shards.uniq!
    
    # Add in the Mastery Shard, modified to make sense with the current crew allocation
    mastery_shard = Shard.new(name: :Mstry, placements: [:Blue, :Orange], color_to_focus: { Red: :Mstry, Orange: :Mstry, Green: :Mstry, Blue: :Mstry, Pink: :Mstry})
    
    mastery_specimen = Set.new()
    0.upto(3) do |i|
      mastery_specimen.add(crew_allocation[i]) unless crew_allocation[i].nil?
    end
    mastery_shard.color_to_focus.delete(:Red) unless mastery_specimen.include?(:Zn)
    mastery_shard.color_to_focus.delete(:Orange) unless mastery_specimen.include?(:Yt)
    mastery_shard.color_to_focus.delete(:Green) unless mastery_specimen.include?(:Vx)
    mastery_shard.color_to_focus.delete(:Blue) unless mastery_specimen.include?(:Wx)
    mastery_shard.color_to_focus.delete(:Pink) unless mastery_specimen.include?(:Xt)    
    eligible_shards.append(mastery_shard)


    # consider every allocation of eligible shards to colors
    useful_links = Set.new()
    focus_to_links = Hash.new { |h, k| h[k] = [] }
    eligible_shards.permutation(5).each do |selected_shards|
      slotted_shards = selected_shards.dup
      
      # CHECK IF THE PLACEMENT OF SHARDS IS LEGAL
      0.upto(4) do |i|
        if slotted_shards[i].placements.include?(COLORS[i])
          slotted_shards[i].cur_placement = COLORS[i]
        else
          slotted_shards[i].cur_placement = nil
        end
      end
      
      # REMOVE ALL ILLEGALLY PLACED SHARD
      slotted_shards.map! do |shard|
        shard.cur_placement.nil? ? nil : shard
      end

      
      # USE potential_foci TO STORE ALL FOCI FOR WHICH ALL SHARDS NEEDED ARE ACTIVE
      potential_foci = Set.new()
      slotted_shards.each do |shard|
        next if shard.nil?
        shard.color_to_focus.values.uniq.each do |focus|
          potential_foci.add(focus)
        end
      end
      unslotted_shards = SHARDS - slotted_shards
      unslotted_shards.each do |shard|
        shard.color_to_focus.values.uniq.each do |focus|
          potential_foci.delete(focus)
        end
      end
      potential_foci -= ineligible_foci
      
      # Terminate if no potential area of focus remains
      next if potential_foci.empty?
 
      # Remove any shards that don't contribute to any potential foci
      slotted_shards.map! do |shard|
        next if shard.nil?
        (shard.color_to_focus.values.uniq & potential_foci.to_a).empty? ? nil : shard
      end
      
      
      # Check which links we need to activate eligible foci
      useful_links.clear
      focus_to_links.clear
      foci_not_needing_links = potential_foci.to_a
      slotted_shards.each do |shard|
        next if shard.nil?
        shard.color_to_focus.each do |color, focus|
          if potential_foci.include?(focus) && shard.cur_placement != color
            link = [color, shard.cur_placement].sort!
            useful_links.add(link)
            focus_to_links[focus].append(link)
            foci_not_needing_links.delete(focus)
          end
        end
      end

      max_links = [6, useful_links.length].floor

      useful_links.to_a.combination(max_links).each do |links_being_checked|
        cur_foci = foci_not_needing_links.dup
        cur_links = []
        focus_to_links.each do |focus, links_for_focus|

          if links_for_focus - links_being_checked == [] && !(focus == :Resou && (cur_foci.include?(:Synth) || cur_foci.include?(:Fixtr))) && !([:Synth, :Fixtr].include?(focus) && cur_foci.include?(:Resou))
            cur_foci.append(focus)
            cur_links += links_for_focus
          end
        end
        cur_foci.sort!.uniq!
        cur_links.sort!.uniq!

        # SKIP SOLUTIONS THAT ARE STRICTLY INFERIOR BASED ON THE FOCI COVERED
        next if dominated_foci.include?(cur_foci)
        
        
        # SKIP SOLUTIONS THAT ARE STRICTLY INFERIOR BASED ON THE NUMBER OF LINKS USED
        next if foci_to_solution.has_key?(cur_foci) && foci_to_solution[cur_foci][2].length < cur_links.length
        

        # Remove unused shards from slotted_shards
        slotted_shards.map! do |shard|
          next if shard.nil?
          (shard.color_to_focus.values & cur_foci.to_a).empty? ? nil : shard
        end

         
        # Remove unused crew from crew_allocation.dup (but if the solution has mastery, keep crew benefitting from it)
        cur_crew = crew_allocation.dup
        unless cur_foci.include?(:Mstry)
          cur_crew.SR = nil unless ([:Fixtr, :Rsh_H, :Rsh_S, :Warp] & cur_foci).any?
          cur_crew.ST = nil unless ([:Fixtr, :Rsh_S] & cur_foci).any?
          cur_crew.ME = nil unless ([:Fixtr, :Spcmn, :Synth, :Mstry] & cur_foci).any?
          cur_crew.SP = nil unless ([:Synth, :Warp] & cur_foci).any?
        end

        # SAVE SOLUTION
        cur_links.sort!.uniq!
        foci_to_solution[cur_foci] = [cur_crew, slotted_shards.dup, cur_links]
        
        # UPDATE DOMINATED FOCI
        (cur_foci.length - 1).downto(1) do |n|
          cur_foci.combination(n).each do |foci_to_skip|
            dominated_foci.add(foci_to_skip)
          end
        end
      end

    end

  end

  spacing = "    "

  header_foci = sym_list_to_string(FOCI_TO_PRINT, 5)
  header_crew = "|SR|ST|ME|SP|"
  header_shards = sym_list_to_string(COLORS, 5)
  header_links = "|" + COLORS.combination(2).map { |a, b| "#{a[0]}#{b[0]}" }.join("|") + "|"
  
  header = [header_foci, header_crew, header_shards, header_links].join(spacing)
  
  puts "\n\n"
  puts "-"*header.length
  label_foci = " Areas of Focus ".center(header_foci.length, "-")
  label_crew = " Crew ".center(header_crew.length, "-")
  label_shards = " Shards ".center(header_shards.length, "-")
  label_links = " Links ".center(header_links.length, "-")
  
  labels = [label_foci, label_crew, label_shards, label_links].join(spacing)
  
  puts labels
  puts header
  puts "-"*header_foci.length + spacing + "-"*header_crew.length + spacing + "-"*header_shards.length + spacing + "-"*header_links.length
  
  foci_to_solution.each do |cur_foci, solution|
    line = "|"
    FOCI_TO_PRINT.each do |focus|
      if cur_foci.include?(focus)
        line += focus.to_s.center(5) + "|"
      else
        line += "  -  |"
      end
    end
    line += spacing + "|"
    line += solution[0].SR.to_s.center(2) + "|"
    line += solution[0].ST.to_s.center(2) + "|"
    line += solution[0].ME.to_s.center(2) + "|"
    line += solution[0].SP.to_s.center(2) + "|"
    line += spacing + sym_list_to_string(solution[1], 5)
    line += spacing + "|"
    
    COLORS.combination(2).each do |color_pair|
      if solution[2].include?(color_pair)
        line += color_pair[0][0].to_s + color_pair[1][0].to_s + "|"
      else
        line += "  |"
      end
    end

    puts line unless dominated_foci.include?(cur_foci)
  end
  puts "-"*header.length
end

usi

