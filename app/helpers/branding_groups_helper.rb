module BrandingGroupsHelper

  def web_safe_fonts
    [
        ['Sans-serif',
          [
              ['Arial', 'Arial, sans-serif'], ['Arial Narrow', 'Arial Narrow, sans-serif'], ['Arial Rounded MT Bold','Arial Rounded MT Bold, sans-serif'],
              ['Calibri', 'Calibri, sans-serif'], ['Candara','Candara, sans-serif'], ['Century Gothic','Century Gothic, sans-serif'],
              ['Gill Sans','Gill Sans, sans-serif'], ['Helvetica','Helvetica, sans-serif'], ['Helvetica Neue','Helvetica Neue, sans-serif'],
              ['Tahoma','Tahoma, sans-serif'], ['Trebuchet MS','Trebuchet MS, sans-serif'], ['Verdana','Verdana, sans-serif']
          ]
        ],
        ['Serif',
          [
              ['Baskerville','Baskerville, serif'], ['Book Antiqua','Book Antiqua, serif'], ['Calisto MT','Calisto MT, serif'],
              ['Cambria','Cambria, serif'], ['Garamond','Garamond, serif'], ['Georgia','Georgia, serif'], ['Goudy Old Style','Goudy Old Style, serif'],
              ['Lucida Bright','Lucida Bright, serif'], ['Palatino','Palatino, serif'], ['Times New Roman','Times New Roman, serif']
          ]
        ],
        ['Monospace',
          [
              ['Andale Mono','Andale Mono, monospace'], ['Consolas','Consolas, monospace'], ['Courier New','Courier New, monospace'],
              ['Lucida Console','Lucida Console, monospace'], ['Lucida Sans Typewriter','Lucida Sans Typewriter, monospace'],
              ['Monaco','Monaco, monospace']
          ]
        ]
    ]
  end
end
