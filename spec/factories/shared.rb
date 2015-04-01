FactoryGirl.define do
  code_words = [ :alpha, :bravo, :charlie, :delta, :echo, :foxtrot, :golf, :hotel ]
  sequence :code_word do |n|
    code_words[(n - 1) % code_words.size]
  end
end