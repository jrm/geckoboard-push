gem 'httparty'
require 'httparty'
require 'json'

module Geckoboard
  class Push
    class << self
      # API configuration
      attr_accessor :api_key
      attr_accessor :api_version
    end

    # Custom error type for handling API errors
    class Error < Exception; end

    include HTTParty
    base_uri 'https://push.geckoboard.com'

    # Initializes the push object for a specific widget
    def initialize(widget_key)
      @widget_key = widget_key
    end

    # Makes a call to Geckoboard to push data to the current widget
    def push(data)
      raise Geckoboard::Push::Error.new("Api key not configured.") if Geckoboard::Push.api_key.nil? || Geckoboard::Push.api_key.empty?
      result = JSON.parse(self.class.post("/#{Geckoboard::Push.api_version || 'v1'}/send/#{@widget_key}", {:body => {:api_key => Geckoboard::Push.api_key, :data => data}.to_json}))
      raise Geckoboard::Push::Error.new(result["error"]) unless result["success"]
      result["success"]
    end
        
    def number_and_secondary_value(value, previous_value, opts)
      d = { :item => [{:text => "", :value => value}, {:text => "", :value => previous_value}] }
      self.push(d.merge(opts))
    end
    
    # Value and previous value should be numeric values
    #def number_and_secondary_value(value, previous_value)
    #  self.push(:item => [{:text => "", :value => value}, {:text => "", :value => previous_value}])
    #end

    # Items should be an array of hashes, each hash containing:
    # - text
    # - type (should be either :alert, or :info, optional)
    def text(items)
      data = items.collect do |item|
        type = case item[:type]
               when :alert
                 1
               when :info
                 2
               else
                 0
               end
        {:text => item[:text], :type => type}
      end
      self.push(:item => data)
    end
    
    def rag(values,labels)
      self.push(:item => [{:value => values[0],:text => labels[0]}, {:value => values[1],:text => labels[1]}, {:value => values[2],:text => labels[2] }])
    end
    
    # Red, amber and green should be values
    #def rag(red, amber, green)
    #  self.push(:item => [{:value => red}, {:value => amber}, {:value => green}])
    #end
    
    def line(values, colour, x_axis, y_axis)
      self.push(:item => values, :settings => {:axisx => x_axis, :axisy => y_axis, :colour => colour})
    end

    # Values should be an array of numeric values
    # Colour, x_axis and y_axis are optional settings
    #def line(values, colour = nil, x_axis = nil, y_axis = nil)
    #  self.push(:item => values, :settings => {:axisx => x_axis, :axisy => y_axis, :colour => colour})
    #end

    # Items should be an array of hashes, each hash containing:
    # - value (numeric value)
    # - label (optional)
    # - colour (optional)
    def pie(items)
      data = items.collect do |item|
        {:value => item[:value], :label => item[:label], :colour => item[:colour]}
      end
      self.push(:item => data)
    end

    # Value, min and max should be numeric values
    def geckometer(value, min, max)
      self.push(:item => value, :min => {:value => min}, :max => {:value => max})
    end

    # Items should be an array of hashes, each hash containing:
    # - value (numeric value)
    # - label (optional)
    # Reverse defaults to false, and when true flips the colours on the widget
    # Hide percentage defaults to false, and when true hides the percentage value on the widget
    def funnel(items, reverse = false, hide_percentage = false)
      data = items.collect do |item|
        {:value => item[:value], :label => item[:label]}
      end
      opts = {:item => data}
      opts[:type] = "reverse" if reverse
      opts[:percentage] = "hide" if hide_percentage
      self.push(opts)
    end
    
    def highcharts_pie(opts = {})
      items = opts.delete(:items)
      title = opts.delete(:title)
      chart = <<-EOS
      {
          chart: {
              backgroundColor: 'rgba(255, 255, 255, 0)',
              plotBackgroundColor: null,
              plotBorderWidth: null,
              plotShadow: false
          },
          credits: {
              enabled: false
          },
          title: {
              text: '#{title}',
              style: {
                color: 'rgb(211, 212, 212)',
                fontWeight: 'normal',
                fontSize: '2.5em',
                fontFamily: 'Helvetica, Arial, sans-serif'
              }
          },
          plotOptions: {
              pie: {
                  animation: false,
                  allowPointSelect: true,
                  cursor: 'pointer',
                  dataLabels: {
                      enabled: true,
                      color: '#ffffff',
                      formatter: function() {
                          return '<b>'+ this.point.name +'</b>: '+ this.y;
                      },
                      style: {
                          fontSize:'1.5em'
                      }
                  }
              }
          },
          series: [{
              type: 'pie',
              data: #{items.map {|d| [ d[:label], d[:value] ]}.to_json}
          }]
      }
      EOS
      self.push(chart)
    end

    def highcharts_stacked_bar(opts)
      title = opts.delete :title
      categories = opts.delete :categories
      series = opts.delete :series
      custom_colors = opts.delete :colors
      default_colors = [
         '#2f7ed8', 
         '#0d233a', 
         '#8bbc21', 
         '#910000', 
         '#1aadce', 
         '#492970',
         '#f28f43', 
         '#77a1e5', 
         '#c42525', 
         '#a6c96a'
      ]
      chart = <<-EOS
      {
              chart: {
                  backgroundColor: 'rgba(255, 255, 255, 0)',
                  type: 'bar'
              },
              colors: #{(custom_colors || default_colors).to_json},
              credits: {
                  enabled: false
              },
              title: {
                  text: '#{title}',
                  style: {
                    color: 'rgb(211, 212, 212)',
                    fontWeight: 'normal',
                    fontSize: '2.5em',
                    fontFamily: 'Helvetica, Arial, sans-serif'
                  }
              },
              xAxis: {
                  categories: #{categories.to_json},
                  labels: {
                    style: {
                      color: "rgb(211, 212, 212)"
                    }
                  }
              },
              yAxis: {
                  allowDecimals: false,
                  min: 0,
                  title: {
                      text: 'Count',
                      style: {
                        color: "rgb(211, 212, 212)"
                      }
                  },
                  labels: {
                    style: {
                      color: "rgb(211, 212, 212)"
                    }
                  }
              },
              legend: {
                  backgroundColor: 'rgba(255, 255, 255, 0)',
                  reversed: true,
                  align: 'center',
                  verticalAlign: 'bottom',
                  itemStyle: {
                      color: 'rgb(211, 212, 212)',
                      fontWeight: 'bold'
                  }
              },
              plotOptions: {
                  bar: {
                    animation: false
                  },
                  series: {
                      stacking: 'normal'
                  }
              },
              series: #{series.to_json}
      }
      EOS
      self.push(chart)
    end

    def highcharts_two_pie(opts)
      title = opts.delete :title
      series = opts.delete :series
      chart = <<-EOS
      {
                  chart: {
                      type: 'pie',
                      backgroundColor: 'rgba(255, 255, 255, 0)',
                  },
                  credits: {
                      enabled: false
                  },
                  title: {
                      text: '#{title}',
                      style: {
                        color: 'rgb(211, 212, 212)',
                        fontWeight: 'normal',
                        fontSize: '2.5em',
                        fontFamily: 'Helvetica, Arial, sans-serif'
                      }
                  },
                  yAxis: {
                      title: {
                          text: '#{title}'
                      }
                  },
                  legend: {
                      backgroundColor: 'rgba(255, 255, 255, 0)',
                      reversed: true,
                      align: 'left',
                      verticalAlign: 'top',
                      itemMarginTop: 15,
                      itemMarginBottom: 15,
                      layout: 'vertical',
                      verticalAlign: 'bottom',
                      itemStyle: {
                          color: 'rgb(211, 212, 212)',
                          fontWeight: 'bold'
                      }
                  },
                  plotOptions: {
                      pie: {
                          animation: false,
                          shadow: false,
                          center: ['50%', '50%'],
                          showInLegend: true
                      }
                  },
                  tooltip: {
              	    valueSuffix: ' alerts'
                  },
                  series: [{
                      name: '#{series[0][:name]}',
                      data: #{series[0][:data].to_json},
                      size: '60%',
                      showInLegend: true,
                      dataLabels: {
                          formatter: function() {
                              return this.y;
                          },
                          color: 'white',
                          distance: -40
                      }
                  }, {
                      name: '#{series[1][:name]}',
                      showInLegend: false,
                      data: #{series[1][:data].to_json},
                      size: '90%',
                      innerSize: '70%',
                      dataLabels: {
                          enabled: true,
                          color: '#eeeeee',
                          connectorColor: '#eeeeee',
                          formatter: function() {
                              // display only if larger than 1
                              return this.y > 1 ? '<b>'+ this.point.name +':</b> '+ this.y : null;
                          }
                      }
                  }]
              }

      EOS
      self.push(chart)
    end
    
    def highcharts_custom(chart)
      self.push(chart.to_json)
    end
    
  end
end
