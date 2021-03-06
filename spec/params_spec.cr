require "./spec_helper"
require "../src/prism/params"

module Prism::Params::Specs
  class SimpleAction
    include Prism::Params

    params do
      param :id, Int32, validate: {min: 42}
      param :value, Int32?
      param :time, Time?
      param :float_value, Float64?
      param :"kebab-param", String?, proc: ->(p : String) { p.upcase }

      param :nest1, nilable: true do
        param :nest2 do
          param :bar, Int32, validate: {max: 42}
        end

        param :foo, String?, proc: ->(p : String) { p.downcase }
        param :arrayParam, Array(UInt8)?, proc: ->(a : Array(UInt8)) { a.map { |i| i * 2 } }
      end

      param :important, Array(String), validate: {size: (1..10)}
    end

    @@last_params = uninitialized ParamsTuple
    class_getter last_params

    def self.call(context)
      params = parse_params(context)
      @@last_params = params
      context.response.print("ok")
    end
  end

  describe SimpleAction do
    context "with valid params" do
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&value=42&time=1526120573870&kebab-param=foo&nest1[nest2][bar]=41&nest1[foo]=BAR&nest1[arrayParam][]=2&nest1[arrayParam][]=3&important[]=foo&important[]=42"))

      it "doesn't halt" do
        response.body.should eq "ok"
      end

      it "has id in params" do
        SimpleAction.last_params[:id].should eq 42
      end

      it "has value in params" do
        SimpleAction.last_params[:value].should eq 42
      end

      it "has time in params" do
        SimpleAction.last_params[:time].should eq Time.epoch_ms(1526120573870_i64)
      end

      it "has kebab-param in params" do
        SimpleAction.last_params["kebab-param"].should eq "FOO"
      end

      it "has nest1 -> nest2 -> bar in params" do
        SimpleAction.last_params[:nest1]?.try &.[:nest2]?.try &.[:bar].should eq 41
      end

      it "has nest1 -> foo in params" do
        SimpleAction.last_params[:nest1]?.try &.[:foo].should eq "bar"
      end

      it "has nest1 -> arrayParam in params" do
        SimpleAction.last_params[:nest1]?.try &.[:arrayParam].should eq [4_u8, 6_u8]
      end

      it "has arrayParam in params" do
        SimpleAction.last_params[:important].should eq ["foo", "42"]
      end
    end

    context "with missing insignificant param" do
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&important[]=42"))

      it "doesn't halt" do
        response.body.should eq "ok"
      end

      it "returns params" do
        SimpleAction.last_params[:id].should eq 42
        SimpleAction.last_params[:important].should eq ["foo", "42"]
      end
    end

    context "with missing significant params" do
      it "raises" do
        expect_raises(ParamNotFoundError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?value=42"))
        end
      end
    end

    context "with invalid params type" do
      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=foo&important[]=foo"))
        end
      end

      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&value=foo"))
        end
      end

      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&nest1[arrayParam][]=foo"))
        end
      end
    end

    context "with invalid params" do
      it "raises" do
        expect_raises(InvalidParamError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=41&important[]=foo"))
        end
      end
    end

    describe "testing certain content types" do
      context "JSON" do
        response = handle_request(SimpleAction, Req.new(
          method: "POST",
          resource: "/",
          body: {
            id:          42,
            float_value: 0.000000000001,
            nest1:       {
              nest2: {
                bar: 41,
              },
              arrayParam: [1, 2],
            },
            important: ["foo"],
          }.to_json,
          headers: HTTP::Headers{
            "Content-Type" => "application/json",
          }
        ))

        it "properly parses float" do
          SimpleAction.last_params[:float_value].should eq 0.000000000001
        end

        it "has nested params" do
          SimpleAction.last_params[:nest1]?.try &.[:nest2]?.try &.[:bar].should eq 41
        end

        it "has array params" do
          SimpleAction.last_params[:important].should eq ["foo"]
        end

        it "has nested array params" do
          SimpleAction.last_params[:nest1]?.try &.[:arrayParam].should eq [2_u8, 4_u8]
        end
      end
    end
  end
end
