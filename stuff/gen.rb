require 'rubygems'
#require "awesome_print"
require 'fastercsv'

require 'redis'
DB = Redis.new()

ALPHABET = ('A'..'Z').to_a + ('0'..'9').to_a

def generate(count)
  count.times do
    DB.sadd('codes', 10.times.map{ ALPHABET.choice }.join)
  end
  DB.scard 'codes'
end

def show_all
  ap DB.smembers 'codes'
end

def save_in_csv(per_row)
  row = []
  all = DB.smembers 'codes'
  FasterCSV.open("temp.csv", "wb") do |csv|
    #while c = DB.spop('codes') do
    all.each do |c|
      row.push(c)
      if row.count == per_row
        csv << row
        row = []
      end
    end
    csv << row unless row == []
  end
end

def generate_and_save(count, per_row)
  row = []
  FasterCSV.open("temp.csv", "wb") do |csv|
    count.times do
      row.push(10.times.map{ ALPHABET.choice }.join)
      if row.count == per_row
        csv << row
        row = []
      end
    end
    csv << row unless row == []
  end
end

def run(count, per_row)
#DB.del 'codes'
generate(count)
#show_all
save_in_csv(per_row)
#generate_and_save(count, per_row)
end

run(1000000,10)
