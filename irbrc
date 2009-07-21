require 'irb/completion'
ARGV.concat [ "--readline", "--prompt-mode", "simple" ]

require 'irb/ext/save-history'
IRB.conf[:SAVE_HISTORY] = 100
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-save-history"

begin
  # load wirble
  #require "rubygems"
  #require 'wirble'

  # start wirble (with color)
  #Wirble.init :skip_prompt=>true
  #Wirble.colorize
rescue LoadError => err
  warn "Couldn't load Wirble: #{err}"
end
#IRB.conf[:PROMPT][:DEFAULT][:PROMPT_C]=Wirble::Colorize.colorize_string(IRB.conf[:PROMPT][:DEFAULT][:PROMPT_C], :light_blue) 
#IRB.conf[:PROMPT][:DEFAULT][:PROMPT_I]=Wirble::Colorize.colorize_string(IRB.conf[:PROMPT][:DEFAULT][:PROMPT_I], :blue) 
#IRB.conf[:PROMPT][:DEFAULT][:PROMPT_S]=Wirble::Colorize.colorize_string(IRB.conf[:PROMPT][:DEFAULT][:PROMPT_S], :yellow) 
#IRB.conf[:PROMPT][:DEFAULT][:RETURN]=Wirble::Colorize.colorize_string(IRB.conf[:PROMPT][:DEFAULT][:RETURN], :brown) 

def ls
	puts "you are in IRB. Take a breathe, rest.. and try again"
end

