require 'spec_helper'

describe "RackRegenerate scheduler" do

  it "should accept out of order jobs and return them all correctly" do
    scheduler = Rack::Regenerate::Tree.new
    [5, 4, 3, 10, 20, 1, 2, 8, 4, 3, 2, 2, 7, 8].each { |i| scheduler.add i, i.to_s }
    scheduler.next(1).should  == ['1']
    scheduler.next(2).should  == ['2', '2', '2']
    scheduler.next(3).should  == ['3', '3']
    scheduler.next(4).should  == ['4', '4']
    scheduler.next(5).should  == ['5']
    scheduler.next(6).should  == nil
    scheduler.next(7).should  == ['7']
    scheduler.next(8).should  == ['8', '8']
    scheduler.next(9).should  == nil
    scheduler.next(10).should == ['10']
    scheduler.next(11).should == nil
    scheduler.next(12).should == nil
    scheduler.next(13).should == nil
    scheduler.next(14).should == nil
    scheduler.next(15).should == nil
    scheduler.next(16).should == nil
    scheduler.next(17).should == nil
    scheduler.next(18).should == nil
    scheduler.next(19).should == nil
    scheduler.next(20).should == ['20']
  end

end
