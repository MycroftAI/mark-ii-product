from http.server import BaseHTTPRequestHandler, HTTPServer
import time
import board
import neopixel

class MyServer(BaseHTTPRequestHandler):
    pixel_pin = board.D12
    num_pixels = 12
    default_brightness = 0.2
    ORDER = neopixel.GRB
    pixels = neopixel.NeoPixel(
            pixel_pin,
            num_pixels,
            brightness=default_brightness,
            auto_write=False,
            pixel_order=ORDER
    )


    def set_led(self, led):
        print("l:%s, r:%s, g:%s, b:%s" % (led['l'], led['r'],led['g'],led['b']))
        self.pixels[ int(led['l']) ] = (int(led['r']), int(led['g']), int(led['b']))
        self.pixels.show()


    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        query = self.path

        page_name = self.path.split("?")[0]
        query_params = {}
        if page_name:
            query = query.replace(page_name+'?','')
            query_params = dict(qc.split("=") for qc in query.split("&"))
            self.set_led(query_params)

        custom_body = "PageName:%s, Params:%s" % (page_name, query_params)
        body = """<html><head></head><body>%s</body></html>""" % (custom_body,)
        self.wfile.write(bytes(body, "utf-8"))

hostName = "0.0.0.0"
serverPort = 8080
if __name__ == "__main__":        
    webServer = HTTPServer((hostName, serverPort), MyServer)
    print("Server started http://%s:%s" % (hostName, serverPort))

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")
