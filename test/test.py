import smtplib
import ssl
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import socket

def test_smtp_connection(host, port=587, username=None, password=None, max_attempts=10):
    """
    Test SMTP connection with STARTTLS on port 587
    """
    print(f"Testing SMTP connection to {host}:{port}")
    print("=" * 50)
    
    success_count = 0
    failure_count = 0
    
    for attempt in range(1, max_attempts + 1):
        print(f"\n--- Attempt {attempt}/{max_attempts} ---")
        
        try:
            # Create SMTP connection
            print(f"Connecting to {host}:{port}...")
            server = smtplib.SMTP(host, port, timeout=30)
            print("✓ SMTP connection established")
            
            # Enable debug output to see what's happening
            server.set_debuglevel(1)
            
            # Check capabilities before TLS
            print("Checking server capabilities before TLS...")
            auth_methods_before = server.esmtp_features.get('auth', '').split() if server.esmtp_features else []
            print(f"Available auth methods before TLS: {auth_methods_before}")
            
            # Start TLS
            print("Starting TLS...")
            server.starttls(context=ssl.create_default_context())
            print("✓ TLS started successfully")
            
            # Check capabilities after TLS
            print("Checking server capabilities after TLS...")
            server.ehlo()  # Re-identify after TLS
            auth_methods_after = server.esmtp_features.get('auth', '').split() if server.esmtp_features else []
            print(f"Available auth methods after TLS: {auth_methods_after}")
            
            # Login if credentials provided
            if username and password:
                print(f"Logging in with username: {username}")
                try:
                    server.login(username, password)
                    print("✓ Login successful")
                except smtplib.SMTPAuthenticationError as auth_error:
                    print(f"✗ Authentication failed: {auth_error}")
                    print(f"  Available auth methods: {auth_methods_after}")
                    if 'NTLM' in auth_methods_after:
                        print("  ⚠️  Server requires NTLM authentication after TLS")
                        print("  ⚠️  Python smtplib doesn't support NTLM by default")
                    raise auth_error
            
            # Test sending a simple message
            print("Testing message sending...")
            msg = MIMEMultipart()
            msg['From'] = username or "test@example.com"
            msg['To'] = "test@example.com"
            msg['Subject'] = f"SMTP Test - Attempt {attempt}"
            
            body = f"This is a test email from attempt {attempt}"
            msg.attach(MIMEText(body, 'plain'))
            
            server.send_message(msg)
            print("✓ Test message sent successfully")
            
            # Close connection
            server.quit()
            print("✓ Connection closed properly")
            
            success_count += 1
            print(f"✓ Attempt {attempt} SUCCESSFUL")
            
        except smtplib.SMTPAuthenticationError as e:
            failure_count += 1
            print(f"✗ SMTP Authentication Error: {e}")
            print(f"  Error code: {e.smtp_code}")
            print(f"  Error message: {e.smtp_error}")
            if 'NTLM' in str(e):
                print("  💡 Consider using port 25 without TLS or install NTLM support")
            
        except smtplib.SMTPConnectError as e:
            failure_count += 1
            print(f"✗ SMTP Connection Error: {e}")
            print(f"  Error code: {e.smtp_code}")
            print(f"  Error message: {e.smtp_error}")
            
        except smtplib.SMTPDataError as e:
            failure_count += 1
            print(f"✗ SMTP Data Error: {e}")
            print(f"  Error code: {e.smtp_code}")
            print(f"  Error message: {e.smtp_error}")
            
        except smtplib.SMTPException as e:
            failure_count += 1
            print(f"✗ SMTP Exception: {e}")
            
        except socket.timeout as e:
            failure_count += 1
            print(f"✗ Socket Timeout: {e}")
            
        except socket.gaierror as e:
            failure_count += 1
            print(f"✗ DNS Resolution Error: {e}")
            
        except Exception as e:
            failure_count += 1
            print(f"✗ Unexpected Error: {type(e).__name__}: {e}")
        
        # Wait a bit between attempts
        if attempt < max_attempts:
            print("Waiting 5 seconds before next attempt...")
            time.sleep(5)
    
    # Summary
    print("\n" + "=" * 50)
    print("TEST SUMMARY")
    print("=" * 50)
    print(f"Total attempts: {max_attempts}")
    print(f"Successful: {success_count}")
    print(f"Failed: {failure_count}")
    print(f"Success rate: {(success_count/max_attempts)*100:.1f}%")
    
    if failure_count > 0:
        print(f"\n⚠️  {failure_count} out of {max_attempts} attempts failed!")
        print("This indicates intermittent connectivity issues.")
    else:
        print(f"\n✅ All {max_attempts} attempts were successful!")

def test_smtp_without_sending(host, port=587, username=None, password=None, max_attempts=10):
    """
    Test SMTP connection without actually sending emails
    """
    print(f"Testing SMTP connection to {host}:{port} (without sending)")
    print("=" * 50)
    
    success_count = 0
    failure_count = 0
    
    for attempt in range(1, max_attempts + 1):
        print(f"\n--- Attempt {attempt}/{max_attempts} ---")
        
        try:
            # Create SMTP connection
            print(f"Connecting to {host}:{port}...")
            server = smtplib.SMTP(host, port, timeout=30)
            print("✓ SMTP connection established")
            
            # Enable debug output
            server.set_debuglevel(1)
            
            # Check capabilities before TLS
            print("Checking server capabilities before TLS...")
            auth_methods_before = server.esmtp_features.get('auth', '').split() if server.esmtp_features else []
            print(f"Available auth methods before TLS: {auth_methods_before}")
            
            # Start TLS
            print("Starting TLS...")
            server.starttls(context=ssl.create_default_context())
            print("✓ TLS started successfully")
            
            # Check capabilities after TLS
            print("Checking server capabilities after TLS...")
            server.ehlo()  # Re-identify after TLS
            auth_methods_after = server.esmtp_features.get('auth', '').split() if server.esmtp_features else []
            print(f"Available auth methods after TLS: {auth_methods_after}")
            
            # Login if credentials provided
            if username and password:
                print(f"Logging in with username: {username}")
                try:
                    server.login(username, password)
                    print("✓ Login successful")
                except smtplib.SMTPAuthenticationError as auth_error:
                    print(f"✗ Authentication failed: {auth_error}")
                    print(f"  Available auth methods: {auth_methods_after}")
                    if 'NTLM' in auth_methods_after:
                        print("  ⚠️  Server requires NTLM authentication after TLS")
                        print("  ⚠️  Python smtplib doesn't support NTLM by default")
                    raise auth_error
            
            # Close connection
            server.quit()
            print("✓ Connection closed properly")
            
            success_count += 1
            print(f"✓ Attempt {attempt} SUCCESSFUL")
            
        except smtplib.SMTPAuthenticationError as e:
            failure_count += 1
            print(f"✗ SMTP Authentication Error: {e}")
            print(f"  Error code: {e.smtp_code}")
            print(f"  Error message: {e.smtp_error}")
            if 'NTLM' in str(e):
                print("  💡 Consider using port 25 without TLS or install NTLM support")
                
        except Exception as e:
            failure_count += 1
            print(f"✗ Attempt {attempt} FAILED: {type(e).__name__}: {e}")
        
        # Wait between attempts
        if attempt < max_attempts:
            print("Waiting 5 seconds before next attempt...")
            time.sleep(5)
    
    # Summary
    print("\n" + "=" * 50)
    print("TEST SUMMARY")
    print("=" * 50)
    print(f"Total attempts: {max_attempts}")
    print(f"Successful: {success_count}")
    print(f"Failed: {failure_count}")
    print(f"Success rate: {(success_count/max_attempts)*100:.1f}%")

def test_smtp_port25_no_ssl(host, port=25, username=None, password=None, max_attempts=2):
    """
    Test SMTP connection on port 25 without SSL/TLS
    """
    print(f"Testing SMTP connection to {host}:{port} (no SSL/TLS)")
    print("=" * 50)
    
    success_count = 0
    failure_count = 0
    
    for attempt in range(1, max_attempts + 1):
        print(f"\n--- Attempt {attempt}/{max_attempts} ---")
        
        try:
            # Create SMTP connection
            print(f"Connecting to {host}:{port}...")
            server = smtplib.SMTP(host, port, timeout=30)
            print("✓ SMTP connection established")
            
            # Enable debug output
            server.set_debuglevel(1)
            
            # Login if credentials provided
            if username and password:
                print(f"Logging in with username: {username}")
                server.login(username, password)
                print("✓ Login successful")
            
            # Close connection
            server.quit()
            print("✓ Connection closed properly")
            
            success_count += 1
            print(f"✓ Attempt {attempt} SUCCESSFUL")
            
        except Exception as e:
            failure_count += 1
            print(f"✗ Attempt {attempt} FAILED: {type(e).__name__}: {e}")
        
        # Wait between attempts
        if attempt < max_attempts:
            print("Waiting 5 seconds before next attempt...")
            time.sleep(5)
    
    # Summary
    print("\n" + "=" * 50)
    print("TEST SUMMARY")
    print("=" * 50)
    print(f"Total attempts: {max_attempts}")
    print(f"Successful: {success_count}")
    print(f"Failed: {failure_count}")
    print(f"Success rate: {(success_count/max_attempts)*100:.1f}%")

if __name__ == "__main__":
    # Configuration - Update these values
    SMTP_HOST = "mail.hissc.com.vn"  # Replace with your SMTP server
    SMTP_PORT = 587
    SMTP_USERNAME = "nlminh"  # Replace with your email
    SMTP_PASSWORD = "FgMBAgABAAH8AwOG4kw63Q"  # Replace with your password
    
    print("SMTP Connection Test Tool")
    print("=" * 50)
    print("This tool will test your SMTP connection 10 times to identify")
    print("intermittent connectivity issues.")
    print()
    
    # Test 1: Port 25 without SSL/TLS
    print("TEST 1: Port 25 Test (no SSL/TLS)")
    test_smtp_port25_no_ssl(SMTP_HOST, 25, SMTP_USERNAME, SMTP_PASSWORD)
    
    print("\n" + "=" * 80)
    
    # Test 2: Full connection test with email sending
    print("TEST 2: Full SMTP Test (with email sending)")
    test_smtp_connection(SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD)
    
    print("\n" + "=" * 80)
    
    # Test 3: Connection test without sending emails
    print("TEST 3: Connection Test (without sending emails)")
    test_smtp_without_sending(SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD)
